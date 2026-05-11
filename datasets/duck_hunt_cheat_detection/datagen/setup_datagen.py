"""
Historical population datagen: 200 clean sessions over the past 6 hours.
All sessions use pick_clean_profile() — no cheaters in history.
"""
import json
import random
import string
import time
import uuid
from datetime import datetime, timezone

import config
from profiles import pick_clean_profile
from simulator import simulate_game, GAME_DURATION_SECS, GAME_DURATION_JITTER_SECS
from telemetry import Telemetry

NUM_SESSIONS = 200
GAME_WINDOW_SECS = 6 * 3600
SCORE_DELAY_SECS = 3
SCORE_DELAY_JITTER_SECS = 3


def random_name() -> str:
    return ''.join(random.choices(string.ascii_uppercase, k=3))


def random_score_data(name: str, game_start_ts: int, game_end_ts: int) -> str:
    hits = random.randint(0, 20)
    shots = hits + random.randint(0, 15)
    score = hits * random.choice([25, 50, 75])
    accuracy = int((hits / shots) * 100) if shots > 0 else 0
    date = datetime.fromtimestamp(game_start_ts / 1000, tz=timezone.utc).isoformat()
    return json.dumps({
        "name": name,
        "score": score,
        "hits": hits,
        "shots": shots,
        "accuracy": accuracy,
        "date": date,
    })


def main():
    telemetry = Telemetry(config.kafka_config(), config.schema_registry_config())
    now = int(time.time() * 1000)
    window_ms = GAME_WINDOW_SECS * 1000

    for i in range(NUM_SESSIONS):
        session_id = str(uuid.uuid4())
        name = random_name()
        profile = pick_clean_profile()

        game_start_ts = now - random.randint(0, window_ms)
        duration_ms = int((GAME_DURATION_SECS + random.uniform(0, GAME_DURATION_JITTER_SECS)) * 1000)
        game_end_ts = game_start_ts + duration_ms
        score_delay_ms = int((SCORE_DELAY_SECS + random.uniform(0, SCORE_DELAY_JITTER_SECS)) * 1000)
        score_ts = game_end_ts + score_delay_ms

        simulate_game(session_id, game_start_ts, game_end_ts, profile, telemetry)
        telemetry.record_control_event(
            session_id, score_ts, "score",
            random_score_data(name, game_start_ts, game_end_ts)
        )
        print(f"[{i + 1}/{NUM_SESSIONS}] session={session_id} name={name} profile={profile.name}")

    telemetry.producer.flush()
    print("Done.")


if __name__ == "__main__":
    main()
