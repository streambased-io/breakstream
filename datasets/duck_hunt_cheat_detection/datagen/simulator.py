"""
Spawn-driven game simulator.

Tick loop runs at TICK_MS (20ms). Every SPAWN_TICKS ticks a new duck spawns.
The player tracks an active target; when a shot plan fires the cursor position
and hit/miss are emitted, then a new target is acquired.

Gun position events are sampled at GUN_INTERVAL_MIN/MAX_MS cadence from the
tick stream — not emitted every tick.
"""
import math
import random
import uuid

from profiles import PlayerProfile

TICK_MS = 20
SPAWN_TICKS = 75

SCREEN_W = 1920
SCREEN_H = 1200
DUCK_START_Y = 875
DUCK_MIN_X = 30
DUCK_MAX_X = 1410
DUCK_HIT_RADIUS = 35  # pixels — cursor must be within this for a clean hit

GUN_INTERVAL_MIN_MS = 100
GUN_INTERVAL_MAX_MS = 250

GAME_DURATION_SECS = 60
GAME_DURATION_JITTER_SECS = 2


class SimDuck:
    def __init__(self, duck_id: str):
        self.duck_id = duck_id
        self.x = float(random.randint(DUCK_MIN_X, DUCK_MAX_X))
        self.y = float(DUCK_START_Y)
        self.direction = random.choice([-1, 1])
        self.straight = False
        self.dx = float(self.direction)
        self.dy = -2.0
        self.alive = True
        self.direction_count = 0

    def tick(self):
        self.direction_count += 1
        if self.direction_count >= 100:
            if random.randint(1, 340) % 5 == 0:
                self.direction = -self.direction
            if random.randint(1, 340) % 5 == 0:
                self.straight = not self.straight
            self.direction_count = 0

        if self.straight:
            self.dy = 0.0
            self.dx = 2.0 * self.direction
        else:
            self.dy = -2.0
            self.dx = float(self.direction)

        self.x += self.dx
        self.y += self.dy

        if self.y < 0 or self.x < 0 or self.x > SCREEN_W:
            self.alive = False


class ShotPlan:
    """Computed at target-acquisition time; fires at shot_ts."""
    __slots__ = ("target_duck_id", "shot_ts", "will_hit", "reaction_ms", "time_on_target_ms")

    def __init__(self, target_duck_id, shot_ts, will_hit, reaction_ms, time_on_target_ms):
        self.target_duck_id = target_duck_id
        self.shot_ts = shot_ts
        self.will_hit = will_hit
        self.reaction_ms = reaction_ms
        self.time_on_target_ms = time_on_target_ms


def _pick_target(ducks: list, profile: PlayerProfile, upcoming_spawn_xy=None):
    """Return duck_id of chosen target or None if no alive ducks."""
    alive = [d for d in ducks if d.alive]
    if not alive:
        return None
    if profile.preaim_lead_ticks > 0 and upcoming_spawn_xy is not None:
        # preaim: pretend the upcoming spawn is already there, steer toward it
        return None  # handled externally; return None so caller knows to preaim
    # closest or random from closest-3
    cx, cy = SCREEN_W / 2, SCREEN_H / 2  # rough cursor centre
    by_dist = sorted(alive, key=lambda d: math.hypot(d.x - cx, d.y - cy))
    pool = by_dist[:3]
    return random.choice(pool).duck_id


def _make_shot_plan(duck_id: str, acquired_ts: int, profile: PlayerProfile) -> ShotPlan:
    reaction_ms = max(30.0, random.gauss(profile.reaction_time_mean_ms, profile.reaction_time_std_ms))
    if profile.triggerbot:
        tot_ms = max(5.0, random.gauss(profile.time_on_target_mean_ms, profile.time_on_target_std_ms))
    else:
        tot_ms = max(20.0, random.gauss(profile.time_on_target_mean_ms, profile.time_on_target_std_ms))
    will_hit = random.random() < profile.p_hit
    shot_ts = int(acquired_ts + reaction_ms + tot_ms)
    return ShotPlan(duck_id, shot_ts, will_hit, reaction_ms, tot_ms)


def _advance_cursor(cx, cy, tx, ty, profile: PlayerProfile):
    """One-tick cursor update. Returns new (cx, cy)."""
    dx = tx - cx
    dy = ty - cy
    cx += dx * profile.cursor_gain + random.gauss(0, profile.cursor_noise_std)
    cy += dy * profile.cursor_gain + random.gauss(0, profile.cursor_noise_std)
    cx = max(0.0, min(float(SCREEN_W), cx))
    cy = max(0.0, min(float(SCREEN_H), cy))
    return cx, cy


def simulate_game(
    session_id: str,
    game_start_ts: int,
    game_end_ts: int,
    profile: PlayerProfile,
    telemetry,
):
    """
    Run the full tick loop for one game, emitting events via telemetry.
    Returns list of raw event dicts (for CapturingTelemetry pattern).
    """
    ducks = []
    spawn_counter = 0
    duck_counter = 0

    # cursor starts roughly centred
    cx, cy = float(SCREEN_W // 2), float(SCREEN_H // 2)

    active_plan: ShotPlan = None
    active_target_duck: SimDuck = None

    # preaim state: coordinates of next-to-spawn duck (computed SPAWN_TICKS ticks ahead)
    preaim_target_xy = None

    # Gun-position emission scheduling
    next_gun_emit_ts = game_start_ts + random.randint(GUN_INTERVAL_MIN_MS, GUN_INTERVAL_MAX_MS)
    last_gun_x, last_gun_y = None, None

    # scripted: track last shot ts to enforce quantised intervals
    last_shot_ts = game_start_ts

    current_ts = game_start_ts

    telemetry.record_control_event(session_id, game_start_ts, "game_start", "")

    while current_ts <= game_end_ts:
        # --- Spawn ---
        spawn_counter += 1
        if spawn_counter >= SPAWN_TICKS:
            duck_counter += 1
            duck_id = str(uuid.uuid4())
            new_duck = SimDuck(duck_id)
            ducks.append(new_duck)
            spawn_counter = 0
            telemetry.record_duck_spawn_event(
                session_id, current_ts, duck_id,
                int(new_duck.x), int(new_duck.y), new_duck.direction
            )
            # if we were preaiming this duck, now it exists — acquire it
            if profile.preaim_lead_ticks > 0 and active_plan is None and active_target_duck is None:
                active_target_duck = new_duck
                active_plan = _make_shot_plan(new_duck.duck_id, current_ts, profile)
            preaim_target_xy = None

        # --- Advance ducks ---
        for d in ducks:
            if d.alive:
                d.tick()
        ducks = [d for d in ducks if d.alive]

        # --- Compute effective cursor target ---
        if profile.preaim_lead_ticks > 0 and active_target_duck is None:
            # pre-steer toward where the next duck will appear ~lead_ticks from now
            # We approximate: next spawn appears at a random x, DUCK_START_Y
            if preaim_target_xy is None and (SPAWN_TICKS - spawn_counter) <= profile.preaim_lead_ticks:
                preaim_target_xy = (
                    float(random.randint(DUCK_MIN_X, DUCK_MAX_X)),
                    float(DUCK_START_Y)
                )
            target_xy = preaim_target_xy if preaim_target_xy else (cx, cy)
        elif active_target_duck is not None and active_target_duck.alive:
            target_xy = (active_target_duck.x, active_target_duck.y)
        else:
            # no target — drift randomly or toward closest alive duck
            alive = [d for d in ducks if d.alive]
            if alive:
                t = min(alive, key=lambda d: math.hypot(d.x - cx, d.y - cy))
                target_xy = (t.x, t.y)
            else:
                target_xy = (cx, cy)

        # --- Advance cursor ---
        cx, cy = _advance_cursor(cx, cy, target_xy[0], target_xy[1], profile)

        # --- Acquire target if none ---
        if active_plan is None and active_target_duck is None:
            alive = [d for d in ducks if d.alive]
            if alive:
                by_dist = sorted(alive, key=lambda d: math.hypot(d.x - cx, d.y - cy))
                pool = by_dist[:min(3, len(by_dist))]
                active_target_duck = random.choice(pool)
                acquired_ts = current_ts

                if profile.scripted_interval_ms > 0:
                    # quantise next shot to a fixed interval from last shot
                    ideal_ts = last_shot_ts + int(profile.scripted_interval_ms)
                    # clamp to [current + 50, game_end]
                    acquired_ts = max(current_ts, ideal_ts - 40)

                active_plan = _make_shot_plan(active_target_duck.duck_id, acquired_ts, profile)

        # --- Fire shot if plan's shot_ts reached ---
        if active_plan is not None and current_ts >= active_plan.shot_ts:
            target = next((d for d in ducks if d.duck_id == active_plan.target_duck_id), None)
            alive = [d for d in ducks if d.alive]

            if active_plan.will_hit and target and target.alive:
                if profile.aimbot:
                    # aimbot snaps cursor to duck regardless of approach
                    shot_x = int(target.x) + random.randint(-3, 3)
                    shot_y = int(target.y) + random.randint(-3, 3)
                else:
                    dist = math.hypot(cx - target.x, cy - target.y)
                    if dist <= DUCK_HIT_RADIUS:
                        shot_x, shot_y = int(cx), int(cy)
                    else:
                        # pull cursor to just inside hit radius
                        angle = math.atan2(target.y - cy, target.x - cx)
                        shot_x = int(target.x - math.cos(angle) * (DUCK_HIT_RADIUS - 5))
                        shot_y = int(target.y - math.sin(angle) * (DUCK_HIT_RADIUS - 5))
                state = "hit"
                remaining = [{"x": int(d.x), "y": int(d.y)} for d in alive if d is not target]
                target.alive = False
            else:
                state = "missed"
                shot_x = int(max(0, min(SCREEN_W, cx + random.gauss(0, 20))))
                shot_y = int(max(0, min(SCREEN_H, cy + random.gauss(0, 20))))
                remaining = [{"x": int(d.x), "y": int(d.y)} for d in alive]

            telemetry.record_shot_event(session_id, current_ts, state, shot_x, shot_y, remaining)
            last_shot_ts = current_ts
            active_plan = None
            active_target_duck = None

        # --- Emit gun position on schedule ---
        if current_ts >= next_gun_emit_ts:
            ix, iy = int(cx), int(cy)
            if ix != last_gun_x or iy != last_gun_y:
                telemetry.record_gun_position_event(session_id, current_ts, ix, iy)
                last_gun_x, last_gun_y = ix, iy
            next_gun_emit_ts = current_ts + random.randint(GUN_INTERVAL_MIN_MS, GUN_INTERVAL_MAX_MS)

        current_ts += TICK_MS

    telemetry.record_control_event(session_id, game_end_ts, "game_stop", "")
