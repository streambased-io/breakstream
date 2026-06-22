import json
import random
import string
import time
import uuid
from datetime import datetime, timedelta, timezone

import config
from telemetry import Telemetry


def random_name() -> str:
    return ''.join(random.choices(string.ascii_uppercase, k=3))

NUM_ROUTES = 100
ROUTE_WINDOW_SECS = 6 * 3600  # 6 hours
ROUTE_DURATION_SECS = 2 * 3600       # 2 hours minimum
ROUTE_DURATION_JITTER_SECS = 3600    # up to 1 extra hour, giving 2–3 hr routes
SCORE_DELAY_SECS = 3
SCORE_DELAY_JITTER_SECS = 3

# Map bounds
MAP_W = 1920
MAP_H = 1200
TRUCK_POSITIONS_MIN = 300
TRUCK_POSITIONS_MAX = 400
TRUCK_INTERVAL_MIN_MS = 100
TRUCK_INTERVAL_MAX_MS = 250
TRUCK_MAX_SPEED = 18   # units per tick
TRUCK_ACCEL = 4        # max velocity change per tick

STOPS_MIN = 8
STOPS_MAX = 12
DELIVERED_RATIO_MIN = 0.80
DELIVERED_RATIO_MAX = 0.95


def random_score_data(name: str, route_start_ts: int, route_end_ts: int) -> str:
    delivered = random.randint(0, 10)
    stops = delivered + random.randint(0, 3)
    score = delivered * random.choice([25, 50, 75])
    delivery_rate = int((delivered / stops) * 100) if stops > 0 else 0
    date = datetime.fromtimestamp(route_start_ts / 1000, tz=timezone.utc).isoformat()
    return json.dumps({
        "name": name,
        "score": score,
        "delivered": delivered,
        "stops": stops,
        "delivery_rate": delivery_rate,
        "date": date,
    })


def generate_stops(route_id: str, route_start_ts: int, route_end_ts: int, telemetry: Telemetry):
    num_stops = random.randint(STOPS_MIN, STOPS_MAX)
    num_delivered = round(num_stops * random.uniform(DELIVERED_RATIO_MIN, DELIVERED_RATIO_MAX))

    duration_ms = route_end_ts - route_start_ts
    stop_times = sorted(
        route_start_ts + random.randint(1000, int(duration_ms - 1000))
        for _ in range(num_stops)
    )

    desired = ['delivered'] * num_delivered + ['undelivered'] * (num_stops - num_delivered)
    random.shuffle(desired)

    for stop_ts, state in zip(stop_times, desired):
        x = random.randint(0, MAP_W)
        y = random.randint(0, MAP_H)
        # Every stop also records a truck position at that location
        telemetry.record_truck_position_event(route_id, stop_ts, x, y)
        telemetry.record_stop_event(route_id, stop_ts, state, x, y)


def generate_truck_positions(route_id: str, route_start_ts: int, route_end_ts: int, telemetry: Telemetry):
    count = random.randint(TRUCK_POSITIONS_MIN, TRUCK_POSITIONS_MAX)
    duration_ms = route_end_ts - route_start_ts

    avg_interval = duration_ms / count
    timestamps = []
    ts = route_start_ts
    for _ in range(count):
        jitter = random.uniform(-avg_interval * 0.3, avg_interval * 0.3)
        interval = max(TRUCK_INTERVAL_MIN_MS, avg_interval + jitter)
        ts += interval
        if ts >= route_end_ts:
            break
        timestamps.append(int(ts))

    x = random.randint(100, MAP_W - 100)
    y = random.randint(100, MAP_H - 100)
    vx = random.uniform(-5, 5)
    vy = random.uniform(-5, 5)
    prev_x, prev_y = None, None

    for t in timestamps:
        vx += random.uniform(-TRUCK_ACCEL, TRUCK_ACCEL)
        vy += random.uniform(-TRUCK_ACCEL, TRUCK_ACCEL)
        vx = max(-TRUCK_MAX_SPEED, min(TRUCK_MAX_SPEED, vx))
        vy = max(-TRUCK_MAX_SPEED, min(TRUCK_MAX_SPEED, vy))

        new_x = int(x + vx)
        new_y = int(y + vy)

        if new_x < 0 or new_x > MAP_W:
            vx = -vx
            new_x = max(0, min(MAP_W, new_x))
        if new_y < 0 or new_y > MAP_H:
            vy = -vy
            new_y = max(0, min(MAP_H, new_y))

        if new_x == prev_x and new_y == prev_y:
            new_x = min(MAP_W, new_x + (1 if vx >= 0 else -1))

        x, y = new_x, new_y
        prev_x, prev_y = x, y

        telemetry.record_truck_position_event(route_id, t, x, y)


def generate_routes(telemetry: Telemetry):
    yesterday = datetime.now(tz=timezone.utc) - timedelta(days=1)
    now = int(yesterday.timestamp() * 1000)
    window_ms = ROUTE_WINDOW_SECS * 1000

    for i in range(NUM_ROUTES):
        route_id = str(uuid.uuid4())
        name = random_name()

        duration_ms = int((ROUTE_DURATION_SECS + random.uniform(0, ROUTE_DURATION_JITTER_SECS)) * 1000)
        route_end_ts = now - random.randint(0, window_ms)
        route_start_ts = route_end_ts - duration_ms

        score_delay_ms = (SCORE_DELAY_SECS + random.uniform(0, SCORE_DELAY_JITTER_SECS)) * 1000
        score_ts = int(route_end_ts + score_delay_ms)

        telemetry.record_control_event(route_id, route_start_ts, "route_start", "")
        generate_truck_positions(route_id, route_start_ts, route_end_ts, telemetry)
        generate_stops(route_id, route_start_ts, route_end_ts, telemetry)
        telemetry.record_control_event(route_id, route_end_ts, "route_end", "")
        telemetry.record_control_event(
            route_id, score_ts, "route_summary",
            random_score_data(name, route_start_ts, route_end_ts)
        )

        print(f"[{i + 1}/{NUM_ROUTES}] route={route_id} name={name} start={route_start_ts} end={route_end_ts} score={score_ts}")

    telemetry.producer.flush()
    print("Done.")


if __name__ == "__main__":
    telemetry = Telemetry(config.kafka_config(), config.schema_registry_config())
    generate_routes(telemetry)
