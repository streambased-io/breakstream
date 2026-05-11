"""
Continuous live datagen with cheat injection.

Modes:
  live  — one game plays out in real time (~60s), then cooldown, repeat
  burst — emit complete game instantly with timestamps in the recent past, then cooldown
"""
import argparse
import json
import random
import string
import time
import uuid
from datetime import datetime, timezone

import config
from profiles import pick_clean_profile, pick_cheat_profile
from simulator import simulate_game, GAME_DURATION_SECS, GAME_DURATION_JITTER_SECS
from telemetry import Telemetry

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


class CapturingTelemetry:
    def __init__(self):
        self.events = []

    def record_shot_event(self, sessionId, timestamp, state, x, y, duck_positions):
        self.events.append((timestamp, ('shot', sessionId, timestamp, state, x, y, duck_positions)))

    def record_gun_position_event(self, sessionId, timestamp, x, y):
        self.events.append((timestamp, ('gun', sessionId, timestamp, x, y)))

    def record_control_event(self, sessionId, timestamp, event_type, data):
        self.events.append((timestamp, ('control', sessionId, timestamp, event_type, data)))

    def record_duck_spawn_event(self, sessionId, timestamp, duck_id, x, y, direction):
        self.events.append((timestamp, ('spawn', sessionId, timestamp, duck_id, x, y, direction)))

    @property
    def producer(self):
        class _NoOp:
            def flush(self): pass
            def poll(self, t): pass
        return _NoOp()


def replay(events, real_telemetry, paced: bool):
    events.sort(key=lambda e: e[0])
    for ts, evt in events:
        if paced:
            wait = (ts - int(time.time() * 1000)) / 1000.0
            if wait > 0:
                time.sleep(wait)
        kind = evt[0]
        if kind == 'shot':
            _, sid, t, st, x, y, dp = evt
            real_telemetry.record_shot_event(sid, t, st, x, y, dp)
        elif kind == 'gun':
            _, sid, t, x, y = evt
            real_telemetry.record_gun_position_event(sid, t, x, y)
        elif kind == 'control':
            _, sid, t, et, dat = evt
            real_telemetry.record_control_event(sid, t, et, dat)
        elif kind == 'spawn':
            _, sid, t, did, x, y, d = evt
            real_telemetry.record_duck_spawn_event(sid, t, did, x, y, d)
        if paced:
            real_telemetry.producer.poll(0)
    real_telemetry.producer.flush()


def play_one_game(real_telemetry, mode: str, cheat_rate: float, allowed_archetypes: list, game_number: int):
    session_id = str(uuid.uuid4())
    name = random_name()

    use_cheat = random.random() < cheat_rate
    profile = pick_cheat_profile(allowed_archetypes) if use_cheat else pick_clean_profile()

    duration_ms = int((GAME_DURATION_SECS + random.uniform(0, GAME_DURATION_JITTER_SECS)) * 1000)
    score_delay_ms = int((SCORE_DELAY_SECS + random.uniform(0, SCORE_DELAY_JITTER_SECS)) * 1000)

    if mode == 'live':
        game_start_ts = int(time.time() * 1000)
    else:
        game_start_ts = int(time.time() * 1000) - duration_ms

    game_end_ts = game_start_ts + duration_ms
    score_ts = game_end_ts + score_delay_ms

    print(f"[game {game_number}] profile={profile.name} session={session_id} name={name} cheat={use_cheat}")

    cap = CapturingTelemetry()
    simulate_game(session_id, game_start_ts, game_end_ts, profile, cap)
    cap.record_control_event(
        session_id, score_ts, "score",
        random_score_data(name, game_start_ts, game_end_ts)
    )

    replay(cap.events, real_telemetry, paced=(mode == 'live'))
    print(f"[game {game_number}] finished session={session_id}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--cheat-rate', type=float, default=0.2)
    parser.add_argument('--archetypes', default='aimbot,scripted,triggerbot,preaim')
    parser.add_argument('--mode', choices=['live', 'burst'], default='live')
    parser.add_argument('--cooldown', type=float, default=None)
    parser.add_argument('--max-games', type=int, default=0)
    args = parser.parse_args()

    cooldown = args.cooldown
    if cooldown is None:
        cooldown = 5.0 if args.mode == 'live' else 20.0

    allowed_archetypes = [a.strip() for a in args.archetypes.split(',') if a.strip()]

    telemetry = Telemetry(config.kafka_config(), config.schema_registry_config())
    print(f"live_datagen mode={args.mode} cooldown={cooldown}s cheat_rate={args.cheat_rate} "
          f"archetypes={allowed_archetypes} max_games={args.max_games or 'unlimited'}")

    n = 0
    try:
        while True:
            play_one_game(telemetry, args.mode, args.cheat_rate, allowed_archetypes, n + 1)
            n += 1
            if args.max_games and n >= args.max_games:
                break
            print(f"  (cooldown {cooldown}s before next game)")
            time.sleep(cooldown)
    except KeyboardInterrupt:
        print("\nStopping. Flushing producer...")
        telemetry.producer.flush()


if __name__ == "__main__":
    main()
