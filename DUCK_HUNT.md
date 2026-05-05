# Duck Hunt Demo

Booth demo that streams Wii-remote shooting events into Kafka and surfaces them as Iceberg via Streambased. The actual game lives in [`../duck-hunt-demo`](../duck-hunt-demo) (sibling repo); this repo orchestrates the supporting infrastructure (Kafka, schema registry, ISK, Iceberg REST + MinIO) and the analyst-facing Jupyter notebook.

## Bring up

```bash
./bin/start.sh demo_duck_hunt
```

Seeds 100 synthetic historical sessions into the coldset (so the notebook has population context to compare against). Environment stays up — `./bin/stop.sh` to tear down.

## Live data feed

Two scripts simulate gameplay so you can develop/test against fresh hotset data without a Wii remote:

```bash
# real-time pace — one game spread over 60s of wall-clock, 5s cooldown, loops forever
./bin/live_datagen.sh

# bursts of full games landing instantly with timestamps in the recent past, 20s of quiet between bursts
./bin/live_datagen.sh --mode burst --cooldown 20

# bounded run for smoke tests
./bin/live_datagen.sh --max-games 3
```

Both run a Python container on the compose network so `kafka1` and `schema-registry` resolve. Ctrl-C to stop.

## Notebook

Jupyter is served at <http://localhost:8889/lab/tree/booth_demo.ipynb> once the environment is up. The notebook covers attention-grab visuals (gun trail, leaderboard, density heatmaps, sunburst, fan chart, etc.), a "conversation kit" of runnable proof cells for sales conversations, an objection cheat sheet, and a live freshness measurement. Notebook source lives at `datasets/duck_hunt/notebooks/booth_demo.ipynb`.
