# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

BreakStream is a Docker-based black-box testing framework for Streambased components. It orchestrates Kafka, Iceberg, Spark, and various Streambased services (ISK, HyperStream, KSI, Slipstream) to run integration tests.

## Commands

### Run a single spec
```bash
./bin/start.sh <spec_name>
```
Example: `./bin/start.sh core_functions`

### Run all specs (excludes demo specs)
```bash
./bin/run_all.sh
```

### Stop environment
```bash
./bin/stop.sh
```

### Setup mode (prepopulate data, skip tests, leave environment running)
```bash
SETUP_MODE=true ./bin/start.sh <spec_name>
```

## Architecture

### Data Model
Streambased exposes a tiered storage model with three logical views:
- **hotset** — Real-time data on Kafka topics (via ISK, exposed as Iceberg-compatible tables)
- **coldset** — Historical data in Iceberg tables on MinIO object storage
- **merged** — Unified virtual view combining both hotset and coldset

Tests typically assert on row counts across these three namespaces using Spark SQL.

### Test Structure
A test consists of three components:

1. **Spec** (`specs/<spec_name>/spec.json`) — Defines which Docker components to start, which datasets to load, and which tests to run:
   ```json
   {
     "components": ["kafka", "iceberg", "datagen-setup", "datagen-background", "streambased"],
     "setup_datasets": ["core"],
     "background_dataset": "core",
     "tests": ["core_functions"]
   }
   ```
   Valid component names map to `environment/*-docker-compose.part.yaml` filenames.

2. **Dataset** (`datasets/<dataset_name>/`) — Contains ShadowTraffic configs for data generation:
   - `setup.json` — One-shot data prepopulation (e.g., 1M rows into Kafka topics)
   - `background.json` — Long-running background traffic during tests
   - `post_setup.sh` — Post-load actions (e.g., copying hotset data to coldset Iceberg tables, configuring Kafka retention)
   - `scala/` — Scala scripts invoked by `post_setup.sh` to move data via `spark-shell`

3. **Test case** (`tests/<test_name>/run.sh`) — Shell script that returns 0 for success, non-zero for failure

### Test Execution Flow
1. Docker Compose file is dynamically assembled from `environment/*-docker-compose.part.yaml` based on spec's `components` array
2. Services are started via Docker Compose
3. Setup datasets are loaded via ShadowTraffic, followed by `post_setup.sh`
4. Background dataset starts generating continuous traffic
5. Test scripts execute (ScalaTest via Spark shell is common)
6. Environment tears down unless it's a demo spec (prefix `demo_`)

### Test Implementation
Tests typically use ScalaTest running in the `spark-iceberg` container. `run.sh` copies the test's `.scala` file and `tests/common/scalatest_common.scala` into the container, concatenates them, and pipes the result to `spark-shell`.

The common file (`tests/common/scalatest_common.scala`) provides a `TestReporter` class that prints pass/fail for each test and calls `System.exit(1)` on any failure.

Standard pattern in `run.sh`:
```bash
docker compose cp $SCRIPT_DIR/test.scala spark-iceberg:/tmp/suite.scala
docker compose cp tests/common/scalatest_common.scala spark-iceberg:/tmp/common.scala
docker compose exec spark-iceberg sh -c "cat /tmp/common.scala /tmp/suite.scala > /tmp/test.scala"
docker compose exec spark-iceberg sh -c "cat /tmp/test.scala | spark-shell --driver-memory 8g --packages org.scalatest:scalatest_2.12:3.0.6"
```

Standard pattern in `test.scala`:
```scala
import org.scalatest.FunSuite
class MySuite extends FunSuite {
  test("description") {
    val count = spark.sql("SELECT COUNT(*) FROM hotset.mytable").head.getLong(0)
    assert(count > 0)
  }
}
try {
  (new MySuite).run(None, new Args(reporter = new TestReporter))
} catch { case e: Throwable => { println(e); System.exit(1) } }
```

### Key Service Ports
| Service | Port |
|---------|------|
| Kafka broker | 9092 |
| Schema Registry | 8081 |
| Spark Connect | 15002 |
| MinIO | 9000 |
| Iceberg REST catalog | 8181 |
| ISK | 11000–11001 |
| HyperStream | 9088 |
| KSI | 9192 |
| Slipstream | 3000 |

### Demo Specs
Specs prefixed with `demo_` are interactive demonstrations. They run a "test" expecting user interaction (via `tests/common/runner_utils.py`) and leave the environment running afterward.

## Requirements
- Docker
- jq
- Java 11+
