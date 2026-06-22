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

Shows the same query rewritten against the Streambased `hotset` and `merged` namespaces. Live Kafka events appear as Iceberg tables with no commit lag. Brian can now join today's live routes against historical baselines in a single SQL statement.

### Part 3 — Under the hood: composable views

Walks through the three logical namespaces exposed by Streambased:

| Namespace | Source | Contents |
|-----------|--------|----------|
| `isk.hotset` | Kafka | Live events, always current |
| `isk.coldset` | Iceberg | Archived historical data |
| `isk.merged` | Both | Automatic union, no duplicates |

Cells query each namespace and show the offset distributions so the boundary between hot and cold data is visible.

### Part 4 — Hot-to-cold transfer

Demonstrates moving data from Kafka to Iceberg with a plain `INSERT INTO coldset SELECT * FROM hotset` statement. Because Kafka is always available as a live view, you choose when it is efficient to archive — there is no forced commit interval.

### Part 5 — Kafka consumers reading archived data (Slipstream)

Simulates Kafka retention expiring so that the topic's earliest offsets are gone. A standard Kafka consumer is shown failing, then reconnecting through the Streambased Slipstream proxy — which transparently serves the missing offsets from Iceberg. Existing consumers require no code changes.

## Supporting UIs

| Tool | URL | Purpose |
|------|-----|---------|
| Jupyter | http://localhost:8889 | The notebook |
| AKHQ | http://localhost:9090 | Kafka topic browser |
| Grafana | http://localhost:7070 | Cluster observability |

## Stopping the environment

```bash
./bin/stop.sh
```

## Running non-interactively (automated / CI)

By default `./bin/start.sh` runs without waiting for keypresses. To add interactive pause-at-each-step behaviour, set `INTERACTIVE_MODE=true`:

```bash
INTERACTIVE_MODE=true ./bin/start.sh
```
