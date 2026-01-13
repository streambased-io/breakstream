# Demo Quickstart Guide

This guide walks through the Streambased demo, demonstrating unified access to streaming and historical data.

## Prerequisites

- Docker and Docker Compose
- jq (JSON processor)
- Java 11+ (for test execution)
- ~8GB free RAM (Docker containers need significant memory)

## Running the Demo

### Step 1: Start the Demo Environment

```bash
./bin/start.sh demo_core
```

This command:
1. Starts the full Streambased stack (Kafka, Iceberg, ISK, KSI, etc.)
2. Generates sample banking data (customers, branches, accounts, transactions)
3. Populates both hotset (Kafka) and coldset (Iceberg)
4. Launches an interactive demo walkthrough

### Step 2: Follow the Interactive Demo

The demo runs in three parts, pausing for you to observe each stage.

#### Part 1: Explore the Environment

The first part shows the available data schemas and record counts:

```sql
-- See available databases
SHOW DATABASES

-- Databases you'll see:
-- hotset   - Live Kafka data
-- coldset  - Historical Iceberg data
-- merged   - Unified view

-- Compare record counts across tiers
SELECT COUNT(*) FROM coldset.transactions  -- Historical data in Iceberg
SELECT COUNT(*) FROM hotset.transactions   -- Recent data in Kafka
SELECT COUNT(*) FROM merged.transactions   -- Combined total
```

**What to observe**: The merged view contains more records than either hotset or coldset alone.

#### Part 2: Move Data from Hotset to Coldset

The second part demonstrates archiving data from Kafka to Iceberg:

```sql
-- Before archival: counts in each tier
SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions
UNION
SELECT 'coldset', COUNT(*) FROM isk.coldset.transactions

-- Archive data: INSERT INTO coldset from hotset
INSERT INTO direct.coldset.transactions
SELECT * FROM isk.hotset.transactions

-- After archival: coldset count increases
SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions
UNION
SELECT 'coldset', COUNT(*) FROM isk.coldset.transactions
```

**What to observe**: Records are copied to coldset, but the merged view count remains the same (no duplicates).

#### Part 3: KSI - Kafka Consumer with Extended Retention

The third part demonstrates KSI (Kafka Service for Iceberg):

```scala
// Standard Kafka consumer connecting to Kafka directly
val kafkaConsumer = new KafkaConsumer(props)
kafkaConsumer.props.put("bootstrap.servers", "kafka1:9092")
// Only sees records still in Kafka

// Same consumer code, but connecting to KSI
val ksiConsumer = new KafkaConsumer(props)
ksiConsumer.props.put("bootstrap.servers", "ksi:9192")
// Sees ALL records - both hot and cold!
```

**What to observe**: Same Kafka consumer API, but KSI returns historical records that are no longer in Kafka.

### Step 3: Explore Further

After the interactive demo completes, the environment remains running. You can:

**Access Spark SQL directly**:
```bash
docker compose exec spark-iceberg spark-sql
```

Then run queries:
```sql
USE isk.merged;
SELECT * FROM transactions LIMIT 10;

-- Aggregations across all data
SELECT BranchID, SUM(TransactionAmount) as total
FROM transactions
GROUP BY BranchID
ORDER BY total DESC;
```

**Access Spark Shell for Scala**:
```bash
docker compose exec spark-iceberg spark-shell
```

**Connect a Kafka consumer to KSI**:
```bash
docker compose exec kafka1 kafka-console-consumer \
  --bootstrap-server ksi:9192 \
  --topic transactions \
  --from-beginning
```

### Step 4: Stop the Environment

```bash
./bin/stop.sh
```

## Sample Data Model

The demo uses a banking scenario with these topics/tables:

| Table | Description | Records |
|-------|-------------|---------|
| `customers` | Customer profiles | ~1,000,000 |
| `branches` | Bank branch locations | 30 |
| `accounts` | Customer accounts | 500 |
| `transactions` | Financial transactions | ~500,000+ |

### Transaction Schema

```json
{
  "TransactionID": "uuid",
  "AccountID": "long",
  "TransactionType": "Deposit|Withdrawal",
  "TransactionAmount": "double",
  "BranchID": "long",
  "CustomerFlaggedFraud": "boolean",
  "TransactionTime": "timestamp"
}
```

## Key Concepts Demonstrated

### 1. Zero-Copy Query

ISK projects Kafka data as Iceberg tables at query time. No ETL pipeline copies data—queries read directly from Kafka.

### 2. Tiered Storage

- **Hotset**: Recent transactions in Kafka (fast writes, limited retention)
- **Coldset**: Historical transactions in Iceberg/MinIO (cost-effective, unlimited)
- **Merged**: Unified view combining both tiers

### 3. Transparent Extended Retention

KSI allows standard Kafka consumers to access historical data without code changes. Consumers get records from Iceberg when requesting offsets no longer in Kafka.

### 4. SQL on Streaming Data

Query live Kafka data using standard SQL through Spark, with no special syntax or connectors.

## Troubleshooting

**Demo hangs during data loading**:
- Check Docker has sufficient memory (8GB+ recommended)
- Run `docker compose logs shadowtraffic_setup` to see data generation progress

**Queries return no data**:
- Ensure the schema name is correct (`isk.hotset`, `direct.coldset`, `isk.merged`)
- Check ISK is running: `docker compose ps directstream`

**KSI connection refused**:
- Verify KSI is healthy: `docker compose ps ksi`
- Check logs: `docker compose logs ksi`

## Related Documentation

- [Streambased Overview](./STREAMBASED_OVERVIEW.md) - Product introduction
- [Architecture Diagram](./ARCHITECTURE.md) - Component interactions
