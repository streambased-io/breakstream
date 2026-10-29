# Streambased Logistics Demo

An interactive Jupyter notebook that shows how Streambased unifies live Kafka streams and historical Iceberg data into a single SQL interface — no pipelines required.

## Prerequisites

- Docker and Docker Compose
- `jq`
- ~8 GB RAM available to Docker

## Starting the environment

```bash
./bin/start.sh
```

This builds and starts the full stack: Kafka, Iceberg (MinIO + REST catalog), the Streambased ISK layer, and a Jupyter server. Data is pre-loaded automatically; startup takes 3–5 minutes.

Once the environment is running, open the notebook:

```
http://localhost:8889
```

Navigate to `logistics_demo.ipynb` and open it.

## Working through the notebook

The notebook tells a single self-contained story. Run cells top to bottom — each section builds on the one before.

### Part 1 — The problem

Introduces Brian, a data scientist trying to analyse truck delivery efficiency. He needs live route data but hits the standard wall: Iceberg only holds cold history, Kafka isn't queryable by his tools. The first few cells demonstrate this gap directly — querying Iceberg for today's data comes back empty.

### Part 2 — Enter Streambased

Shows the same query rewritten against the Streambased `hotset` and `union` namespaces. Live Kafka events appear as Iceberg tables with no commit lag. Brian can now join today's live routes against historical baselines in a single SQL statement.

### Part 3 — Under the hood: composable views

Walks through the three logical namespaces exposed by Streambased:

| Namespace | Source | Contents |
|-----------|--------|----------|
| `isk.hotset` | Kafka | Live events, always current |
| `isk.coldset` | Iceberg | Archived historical data |
| `isk.union` | Both | Automatic union, no duplicates |

Cells query each namespace and show the offset distributions so the boundary between hot and cold data is visible.

### Part 4 — Hot-to-cold transfer

Demonstrates moving data from Kafka to Iceberg with a single call to Hyperstream's roll endpoint (`POST /api/union/roll`). Because Kafka is always available as a live view, you choose when it is efficient to archive — there is no forced commit interval.

### Part 5 — Kafka consumers reading archived data (Slipstream)

Simulates Kafka retention expiring so that the topic's earliest offsets are gone. A standard Kafka consumer is shown failing, then reconnecting through the Streambased Slipstream proxy — which transparently serves the missing offsets from Iceberg. Existing consumers require no code changes.

## Supporting UIs

| Tool | URL | Purpose |
|------|-----|---------|
| Jupyter | http://localhost:8889 | The notebook |

## Stopping the environment

```bash
./bin/stop.sh
```

## Running non-interactively (automated / CI)

By default `./bin/start.sh` runs without waiting for keypresses. To add interactive pause-at-each-step behaviour, set `INTERACTIVE_MODE=true`:

```bash
INTERACTIVE_MODE=true ./bin/start.sh
```

## Union roll demo

`./bin/start_tests.sh union_roll` starts a stack where the `union-roll` service calls Hyperstream's `POST /api/union/roll` for `branches`, `transactions` and `customers` every `UNION_ROLL_INTERVAL_SECONDS` (default 300), then checks `directstream_union_unrolled_epochs` and the union counts. The roll loop and the demos' roll calls share `bin/lib/union_roll.sh`.

Every spec that reads `isk.union.*` or fills `direct.coldset.*` (`union_roll`, `demo_core`, `demo_cdc`, `demo_logistics`) uses the `streambased-union-roll` component: the `streambased` part plus the union-view settings (coldset alias, combined CDC view, Hyperstream roll). The coldset is written only by rolls; the demo datasets roll once during setup. The `core` dataset and the `ksi` specs still copy hotset to coldset with Spark and use the plain `streambased` part.

To run with locally built images, set `DIRECTSTREAM_IMAGE`, `HYPERSTREAM_IMAGE` and `SLIPSTREAM_IMAGE` (defaults: `streambased/directstream:latest`, `streambased/dev-hyperstream:latest`, `streambased/dev-slipstream:latest`). `compose pull` fails for a local-only image name and leaves it untouched.

`datasets/union_roll/setup.json` mirrors `datasets/demo/setup.json`; the spec keeps `datagen-setup` because the topics `branches` and `customers` exist only through that setup, and `transactions` also comes from the `demo` background dataset.
