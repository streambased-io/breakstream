# BreakStream

Docker-based demo and testing environment for Streambased components.

## What is Streambased?

Streambased unifies Apache Kafka and Apache Iceberg, enabling real-time analytics across streaming and historical data without traditional batch pipelines. See [Streambased Overview](docs/STREAMBASED_OVERVIEW.md) for details.

## Demo Quickstart

Run the interactive demo to see Streambased in action:

```bash
./bin/start.sh
```

This starts the full stack and walks through:
1. **Unified data views** - Query streaming (hotset) and historical (coldset) data with SQL
2. **Data tiering** - Move data from Kafka to Iceberg
3. **Extended retention** - Kafka consumers reading historical data via KSI

See [Demo Quickstart Guide](docs/QUICKSTART.md) for the full walkthrough.

## Documentation

- [Streambased Overview](docs/STREAMBASED_OVERVIEW.md) - Product introduction and concepts
- [Architecture](docs/ARCHITECTURE.md) - Component diagram and interactions
- [Demo Quickstart](docs/QUICKSTART.md) - Hands-on walkthrough

## Requirements

- Docker and Docker Compose
- jq
- Java 11+
- ~8GB RAM available for Docker

## Commands

```bash
# Run interactive demo
./bin/start.sh

# Run automated tests
./bin/start.sh core_functions

# Run all test specs
./bin/run_all.sh

# Stop environment
./bin/stop.sh

# Setup mode (start environment, skip tests)
SETUP_MODE=true ./bin/start.sh core_functions
```

---

## Test Framework

BreakStream also serves as a black-box testing framework for Streambased components.

### Test Structure

A test consists of 3 components:

1. **Spec** (`specs/<name>/spec.json`) - Defines Docker components, datasets, and tests to run:
   ```json
   {
       "components": ["kafka", "iceberg", "datagen-setup", "datagen-background", "streambased"],
       "setup_datasets": ["core"],
       "background_dataset": "core",
       "tests": ["core_functions"]
   }
   ```

2. **Datasets** (`datasets/<name>/`) - ShadowTraffic configs for data generation:
   - `setup.json` - One-shot data prepopulation
   - `background.json` - Continuous background traffic
   - `post_setup.sh` - Post-load actions (e.g., copy to Iceberg)

3. **Test Cases** (`tests/<name>/run.sh`) - Shell script returning 0 for success

### Demo Specs

Specs prefixed with `demo_` are interactive demonstrations that:
- Expect user interaction (press key to continue)
- Leave environment running after completion
- Don't verify correctness, just demonstrate features
