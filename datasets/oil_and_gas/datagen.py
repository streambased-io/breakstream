"""
Generates a day's worth of hydraulic fracturing jobs.

Each job is one horizontal well being fracked stage by stage, toe to heel:
  - pump_telemetry       treating pressure / slurry rate / proppant concentration
                         sampled throughout the job (high volume)
  - frac_stages          one event per stage when it finishes: 'completed', or
                         'screenout' if proppant bridged and pressure ran away
  - well_control_events  job_start, job_end and a job_summary JSON blob

Screenout stages carry a recognisable signature in pump_telemetry: in the last
part of the stage the treating pressure climbs steeply while the rate falls
away. That is the signal the notebook's story is built around.
"""
import json
import math
import random
import uuid
from datetime import datetime, timedelta, timezone

import config
from telemetry import Telemetry

NUM_JOBS = 100
JOB_WINDOW_SECS = 6 * 3600           # jobs finished across the last 6 hours (of yesterday)
JOB_DURATION_SECS = 2 * 3600         # 2 hours minimum
JOB_DURATION_JITTER_SECS = 3600      # up to 1 extra hour, giving 2-3 hr jobs
SUMMARY_DELAY_SECS = 3
SUMMARY_DELAY_JITTER_SECS = 3

TELEMETRY_READINGS_MIN = 300
TELEMETRY_READINGS_MAX = 400

STAGES_MIN = 8
STAGES_MAX = 12
COMPLETED_RATIO_MIN = 0.80
COMPLETED_RATIO_MAX = 0.95

# Wellbore geometry (feet). Stage 1 sits at the toe; later stages walk back to the heel.
HEEL_MD_MIN = 9_000
HEEL_MD_MAX = 11_000
LATERAL_LENGTH_MIN = 7_000
LATERAL_LENGTH_MAX = 10_000

# Pumping behaviour
BASE_PRESSURE_MIN = 6_800
BASE_PRESSURE_MAX = 8_200
DESIGN_RATE_MIN = 80.0
DESIGN_RATE_MAX = 100.0
MAX_PPA_MIN = 2.0
MAX_PPA_MAX = 4.0
PRESSURE_PER_PPA = 350.0
SCREENOUT_PEAK_MIN = 11_000
SCREENOUT_PEAK_MAX = 12_500
SCREENOUT_ONSET = 0.55               # fraction through a screenout stage where net pressure starts climbing -
                                     # gradual at first, then running away, so there are a few minutes of warning
STAGE_DESIGN_PROPPANT_MIN = 300_000
STAGE_DESIGN_PROPPANT_MAX = 450_000

FIELDS = ["EAGLE", "PERMIAN", "BAKKEN", "WOLFCAMP", "HAYNES", "MARCELLUS", "SPRABERRY", "DELAWARE"]
PADS = ["NORTH", "SOUTH", "EAST", "WEST", "RIDGE", "CREEK", "MESA"]


def random_well_name() -> str:
    return f"{random.choice(FIELDS)}-{random.randint(1, 48)}{random.choice(['H', 'HA', 'HB', 'HC'])}"


def plan_job(job_start_ts: int, job_end_ts: int):
    """Lay out the stages for a job: where along the lateral, when they pump, and how they end."""
    num_stages = random.randint(STAGES_MIN, STAGES_MAX)
    num_completed = round(num_stages * random.uniform(COMPLETED_RATIO_MIN, COMPLETED_RATIO_MAX))
    states = ['completed'] * num_completed + ['screenout'] * (num_stages - num_completed)
    random.shuffle(states)

    heel_md = random.randint(HEEL_MD_MIN, HEEL_MD_MAX)
    toe_md = heel_md + random.randint(LATERAL_LENGTH_MIN, LATERAL_LENGTH_MAX)
    spacing = (toe_md - heel_md) / num_stages

    # Stage windows: roughly equal slices of the job with some jitter, back to back.
    weights = [random.uniform(0.8, 1.2) for _ in range(num_stages)]
    total = sum(weights)
    duration_ms = job_end_ts - job_start_ts
    stages = []
    t = job_start_ts
    for i, (state, w) in enumerate(zip(states, weights)):
        end = job_end_ts if i == num_stages - 1 else int(t + duration_ms * w / total)
        stages.append({
            "stage_number": i + 1,
            "state": state,
            "start_ts": int(t),
            "end_ts": end,
            "measured_depth_ft": int(toe_md - (i + 0.5) * spacing + random.uniform(-40, 40)),
            "max_ppa": random.uniform(MAX_PPA_MIN, MAX_PPA_MAX),
            "design_rate": random.uniform(DESIGN_RATE_MIN, DESIGN_RATE_MAX),
            "screenout_peak": random.uniform(SCREENOUT_PEAK_MIN, SCREENOUT_PEAK_MAX),
        })
        t = end
    return stages


def pumping_state(stage, base_pressure, f):
    """Pressure / rate / proppant at fraction f (0..1) through a stage."""
    # Pad (no sand) -> ramped slurry -> flush (no sand)
    if f < 0.15:
        proppant = 0.0
    elif f < 0.85:
        proppant = stage["max_ppa"] * (0.15 + 0.85 * (f - 0.15) / 0.70)
    else:
        proppant = 0.0

    rate = stage["design_rate"] * min(1.0, f / 0.08) if f > 0 else 0.0
    pressure = base_pressure + PRESSURE_PER_PPA * proppant + 900 * min(1.0, f / 0.08)

    if stage["state"] == "screenout" and f >= SCREENOUT_ONSET:
        # Proppant bridges in the fractures: pressure runs away, the crew cuts rate.
        g = (f - SCREENOUT_ONSET) / (1 - SCREENOUT_ONSET)
        ramp = (math.exp(3 * g) - 1) / (math.exp(3) - 1)
        pressure = pressure + (stage["screenout_peak"] - pressure) * ramp
        rate = rate * (1 - 0.75 * ramp)
        proppant = stage["max_ppa"] * (1 - 0.6 * ramp)

    pressure += random.gauss(0, 120)
    rate += random.gauss(0, 1.5)
    proppant += random.gauss(0, 0.05) if proppant > 0 else 0.0
    return round(max(0.0, pressure), 1), round(max(0.0, rate), 2), round(max(0.0, proppant), 2)


def generate_pump_telemetry(well_id: str, job_start_ts: int, job_end_ts: int, stages, telemetry: Telemetry):
    count = random.randint(TELEMETRY_READINGS_MIN, TELEMETRY_READINGS_MAX)
    duration_ms = job_end_ts - job_start_ts
    avg_interval = duration_ms / count
    base_pressure = random.uniform(BASE_PRESSURE_MIN, BASE_PRESSURE_MAX)

    ts = job_start_ts
    idx = 0
    while True:
        ts += avg_interval + random.uniform(-avg_interval * 0.3, avg_interval * 0.3)
        if ts >= job_end_ts:
            break
        while idx < len(stages) - 1 and ts >= stages[idx]["end_ts"]:
            idx += 1
        stage = stages[idx]
        f = (ts - stage["start_ts"]) / max(1, stage["end_ts"] - stage["start_ts"])
        pressure, rate, proppant = pumping_state(stage, base_pressure, min(1.0, max(0.0, f)))
        telemetry.record_pump_telemetry_event(well_id, int(ts), stage["stage_number"], pressure, rate, proppant)


def generate_frac_stages(well_id: str, stages, telemetry: Telemetry):
    placed_total = 0
    for stage in stages:
        design = random.randint(STAGE_DESIGN_PROPPANT_MIN, STAGE_DESIGN_PROPPANT_MAX)
        placed = design if stage["state"] == "completed" else int(design * random.uniform(0.35, 0.75))
        placed_total += placed
        telemetry.record_frac_stage_event(well_id, stage["end_ts"], stage["stage_number"], stage["state"],
                                          stage["measured_depth_ft"], placed)
    return placed_total


def job_summary(well_name: str, job_start_ts: int, stages, proppant_placed_lbs: int) -> str:
    completed = sum(1 for s in stages if s["state"] == "completed")
    return json.dumps({
        "well_name": well_name,
        "pad": f"{random.choice(PADS)}-{random.randint(1, 20)}",
        "stages": len(stages),
        "completed": completed,
        "screenouts": len(stages) - completed,
        "completion_rate": int(100 * completed / len(stages)),
        "proppant_placed_lbs": proppant_placed_lbs,
        "date": datetime.fromtimestamp(job_start_ts / 1000, tz=timezone.utc).isoformat(),
    })


def emit_job(telemetry: Telemetry, job_end_ts: int):
    well_id = str(uuid.uuid4())
    well_name = random_well_name()

    duration_ms = int((JOB_DURATION_SECS + random.uniform(0, JOB_DURATION_JITTER_SECS)) * 1000)
    job_start_ts = job_end_ts - duration_ms
    summary_ts = int(job_end_ts + (SUMMARY_DELAY_SECS + random.uniform(0, SUMMARY_DELAY_JITTER_SECS)) * 1000)

    stages = plan_job(job_start_ts, job_end_ts)
    telemetry.record_control_event(well_id, job_start_ts, "job_start", "")
    generate_pump_telemetry(well_id, job_start_ts, job_end_ts, stages, telemetry)
    placed = generate_frac_stages(well_id, stages, telemetry)
    telemetry.record_control_event(well_id, job_end_ts, "job_end", "")
    telemetry.record_control_event(well_id, summary_ts, "job_summary",
                                   job_summary(well_name, job_start_ts, stages, placed))
    telemetry.producer.flush()
    return well_id, well_name, job_start_ts


def generate_jobs(telemetry: Telemetry):
    yesterday = datetime.now(tz=timezone.utc) - timedelta(days=1)
    now = int(yesterday.timestamp() * 1000)
    window_ms = JOB_WINDOW_SECS * 1000

    for i in range(NUM_JOBS):
        job_end_ts = now - random.randint(0, window_ms)
        well_id, well_name, job_start_ts = emit_job(telemetry, job_end_ts)
        print(f"[{i + 1}/{NUM_JOBS}] well={well_id} name={well_name} start={job_start_ts} end={job_end_ts}")

    telemetry.producer.flush()
    print("Done.")


if __name__ == "__main__":
    telemetry = Telemetry(config.kafka_config(), config.schema_registry_config())
    generate_jobs(telemetry)
