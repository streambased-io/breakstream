# Duck Hunt — Cheat Detection Demo

Booth demo (Current London, 2026) that scores each completed duck-hunt game for cheating using an LLM. This is the third pillar of a three-pillar Streambased pitch: pillar 1 is Grafana on the live Kafka stream (operational), pillar 2 is a notebook on the Iceberg coldset (analytical), and this one is the AI/ML pillar — an LLM reasons over the just-completed game and the historical population from Iceberg, with **no stateful pre-aggregation**.

Self-contained inside this repo: the synthetic game simulator, profiles (clean + 4 cheat archetypes), live datagen, and the analyst notebook all live under `datasets/duck_hunt_cheat_detection/`. Designed to run on its own laptop alongside the pillar-1/-2 demo on the booth.

## Bring up

```bash
export OPENAI_API_KEY=sk-...           # required for LLM verdicts
./bin/start.sh demo_duck_hunt_cheat_detection
```

Seeds 200 synthetic historical sessions of **clean** play (no cheaters in history) into the coldset, so the notebook has a clean-population baseline to score against. Environment stays up; `./bin/stop.sh` to tear down.

If `OPENAI_API_KEY` is unset, the notebook still runs but falls back to a placeholder verdict (`{verdict: clean, reasoning: "LLM not configured"}`). Set it before bring-up so docker-compose interpolation picks it up.

## Live data feed (with cheat injection)

Continuous stream of new games with configurable cheat-rate and archetype mix, so the notebook has something to score:

```bash
# default: real-time pace (60s/game), 5s cooldown, 1-in-5 games is a cheater
./bin/live_datagen_cheat.sh

# burst mode — whole game lands instantly with backdated timestamps, 20s between bursts
./bin/live_datagen_cheat.sh --mode burst --cooldown 5

# stress one archetype
./bin/live_datagen_cheat.sh --cheat-rate 0.5 --archetypes aimbot

# bounded smoke test
./bin/live_datagen_cheat.sh --max-games 3
```

### Batch injection for testing

Burst mode + `--max-games` injects a fixed number of games back-to-back, fast — ideal for evaluating the notebook against a known mix.

```bash
# 20 games back-to-back, 1s between (~20s total)
./bin/live_datagen_cheat.sh --mode burst --max-games 20 --cooldown 1

# 10 games, half cheaters, all aimbots — focused detection test
./bin/live_datagen_cheat.sh --mode burst --max-games 10 --cheat-rate 0.5 --archetypes aimbot

# instant-fire: zero cooldown, 20 mixed games
./bin/live_datagen_cheat.sh --mode burst --cooldown 0 --max-games 20
```

Each game's `[game N] profile=<name> session=<uuid>` print lets you correlate ground-truth vs. notebook verdict afterwards.

Each game prints `[game N] profile=<name> session=<uuid>` to stdout so you can correlate booth-side what's being injected vs. what the notebook flags.

### Flags

| flag | default | meaning |
|---|---|---|
| `--cheat-rate F` | `0.2` | probability each game uses a cheat profile |
| `--archetypes LIST` | `aimbot,scripted,triggerbot,preaim` | comma-separated allowed cheat archetypes |
| `--mode live\|burst` | `live` | live = real-time pace, burst = instant emit |
| `--cooldown N` | 5 (live) / 20 (burst) | seconds between games |
| `--max-games N` | `0` (unlimited) | stop after N games |

### Cheat archetypes

- **aimbot** — superhuman reaction time (~100ms), near-perfect accuracy (~97%) flat across duck speeds. Time-on-target and cursor smoothness look normal.
- **scripted** — inter-shot intervals quantised to a fixed cadence (~800ms). Reaction time, accuracy and cursor jitter look human.
- **triggerbot** — normal human reaction time and accuracy, but time-on-target collapses to ~15ms (fires the instant the cursor crosses a duck).
- **preaim** — cursor pre-positions near where the next duck will spawn before the spawn happens. Reaction time post-spawn is suspiciously low.

Clean players are skill-varied across four sub-styles: sniper, spray_and_pray, improver, panicker — with realistic skill bands. The historical coldset is generated entirely from these.

## Notebook

Jupyter is served at <http://localhost:8889/lab/tree/cheat_detection.ipynb> once the environment is up. Source lives at `datasets/duck_hunt_cheat_detection/notebooks/cheat_detection.ipynb` — copies into `environment/notebooks/` on `start.sh` (the staged copy is what Jupyter sees).

### Cell flow

1. Markdown intro
2. Imports + Spark Connect
3. **Load historical population** from `coldset.shots / duck_spawns / gun_positions` — sampled fraction controllable via `POPULATION_SAMPLE_FRACTION` (default `1.0` — full 200 sessions; drop for faster iteration)
4. **Compute population metrics** (one-time; helper funcs live here)
5. Find latest `game_stop` from `merged.control_events`
6. **Load current game events** from `merged.*`
7. **Compute current-game metrics**
8. Build LLM prompt — toggle `USE_DISTRIBUTIONAL_STATS`:
   - `True` (default) — send population percentile ladder (min/p5/p10/p25/median/p75/p90/p95/max + mean + σ) per metric, plus the current game's six values. Compact (~1-2 KB), focused signal.
   - `False` — send raw event CSVs (no pre-computed metrics, LLM must derive everything). Heavier prompt; needs a stronger model.
9. Call OpenAI with structured output (`submit_verdict` tool). Verdict shape: `{verdict, archetype, confidence, reasoning, cited_features}`.
10. Render 6 panels (reaction time, ISI variance, cursor jerk, accuracy vs duck speed, time-on-target, pre-aim distance) — population distribution overlaid with current game's value. Outer border green/red per verdict; cited features get bolded/coloured panel borders.
11. Last-flagged-game navigation (re-runnable).

### Knobs

| where | constant | default | purpose |
|---|---|---|---|
| cell 3 | `POPULATION_SAMPLE_FRACTION` | `1.0` | what fraction of historical sessions to load for context (drop to 0.1–0.5 for faster iteration on small Spark clusters) |
| cell 8 | `USE_DISTRIBUTIONAL_STATS` | `True` | percentile ladder vs raw events in prompt |
| cell 9 | `model="gpt-4.1-mini"` | — | swap to `gpt-4.1`, `o4-mini`, etc. for better reasoning |

### Re-running per game

After the first end-to-end pass, the population load and population metrics are static. For each new game:
- Run cell 5 (find latest game_stop)
- Run cells 6, 7 (load + compute current-game metrics)
- Run cells 8, 9 (prompt + LLM)
- Run cell 10 (panels)

Population cells (3, 4) only re-run if you want to reload the historical coldset.

## Architecture (one-liner pitch for booth)

> Three workloads, one substrate. Grafana on the live Kafka stream (operational). Notebook on the Iceberg coldset (analytical). LLM scoring each completed game against the full historical population — treating the whole game as a sequence rather than isolated shots, with no stateful aggregation to maintain. The structural advantage over Flink: you don't have to name your aggregations before the data arrives.
