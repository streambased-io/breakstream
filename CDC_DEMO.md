# CDC Demo

An interactive demonstration of how Streambased I.S.K. handles Change Data Capture (CDC) streams natively — no custom ETL, no duplicate rows, no ghost records.

## What it shows

A CDC stream is a Kafka topic where each message carries a Debezium envelope: an operation type (`c`/`u`/`d`) and before/after payloads. Without CDC-aware processing, querying such a topic as a table produces duplicates for updated records and stale rows for deleted ones.

This demo walks through three capabilities:

1. **Envelope unwrapping** — I.S.K. exposes the CDC topic as a clean Iceberg table. The `op`, `before`, and `after` fields are transparent; queries see only the current-state payload columns.

2. **CDC deduplication** — Background traffic continuously updates existing orders (PENDING → SHIPPED). The hotset always shows one row per order key at its latest state. `COUNT(*) == COUNT(DISTINCT OrderID)` at all times.

3. **Atomic coldset roll** — A single `MERGE INTO` statement unioning `isk.hotset.orders` and `isk.cdc_deletes.orders` rolls all changes into Iceberg atomically: updates existing rows, inserts new ones, and deletes tombstoned records in one commit.

## Data model

Single topic: **`orders`** (Debezium CDC envelope, Avro key + value via Schema Registry)

| Phase | What happens |
|-------|-------------|
| Setup | 500 CREATE events (orders 1–500, status `PENDING`) loaded into Kafka, then rolled to Iceberg coldset. Kafka is drained so the demo starts with a clean hotset. |
| Background | Two continuous generators: new order creates (IDs 1001+, 1/s) and status updates to orders 1–500 (PENDING → SHIPPED, 1/s). |
| Mid-demo | 100 DELETE events for orders 1–100 injected into the CDC stream. |

## Run it

```bash
./bin/start.sh demo_cdc
```

Requires Docker, `jq`, and Java 11+. Allow ~5 minutes for initial setup (image pulls + data load).

## Demo walkthrough

The demo pauses at each step. Press **Enter** to advance.

### Part 1 — Environment exploration

- `SHOW DATABASES` — three views: `hotset`, `coldset`, `merged`
- `DESCRIBE isk.hotset.orders` — envelope unwrapped; schema shows payload columns (OrderID, CustomerID, Status, Amount), not CDC envelope fields
- Row counts across all three views
- Sample records from the hotset showing SHIPPED status (updates already applied)

### Part 2 — CDC deduplication and updates

- `COUNT(*) vs COUNT(DISTINCT OrderID)` from hotset — both equal, confirming no duplicate rows from updates
- Updated orders in hotset show SHIPPED; same records in coldset still show PENDING (original); merged shows SHIPPED (hotset wins)
- Pre-delete count recorded

Background stops. 100 DELETE events for orders 1–100 are published to Kafka.

### Part 2b — Delete propagation

- Post-delete count from `isk.merged.orders` — down by ~100
- Deleted orders are suppressed in all views; the physical coldset rows still exist but are hidden by I.S.K.'s CDC key index

### Part 3 — Atomic roll to coldset

Single `MERGE INTO` statement using a UNION of two I.S.K. virtual views as source:

```sql
MERGE INTO direct.coldset.orders t
USING (
  -- live records: CDC-deduplicated current state
  SELECT OrderID, CustomerID, Status, Amount, kafka_partition, kafka_offset,
         false as _to_delete
  FROM isk.hotset.orders
  UNION ALL
  -- tombstones: keys deleted from the CDC stream
  SELECT OrderID, null, null, null, kafka_partition, delete_kafka_offset,
         true as _to_delete
  FROM isk.cdc_deletes.orders
) s
ON t.OrderID = s.OrderID
WHEN MATCHED AND s._to_delete     THEN DELETE
WHEN MATCHED AND NOT s._to_delete THEN UPDATE SET ...
WHEN NOT MATCHED AND NOT s._to_delete THEN INSERT ...
```

Because I.S.K. guarantees deleted keys are absent from `isk.hotset.orders`, the two sources are disjoint — each OrderID appears exactly once in the UNION, making the MERGE safe as a single Iceberg commit.

After the roll:
- Orders 1–100: deleted from coldset
- Orders 101–500: updated in coldset (PENDING → SHIPPED)
- Orders 1001+: inserted into coldset
- Merged view remains correct as Kafka retention expires the rolled offsets

## Explore further

After the demo the environment stays running. To inspect directly:

```bash
cd environment
docker compose exec -it spark-iceberg spark-shell

# Inside spark-shell:
spark.sql("SELECT * FROM isk.merged.orders LIMIT 20").show()
spark.sql("SELECT * FROM isk.cdc_deletes.orders").show()
spark.sql("SELECT Status, COUNT(*) FROM direct.coldset.orders GROUP BY Status").show()
```

Stop the environment when done:

```bash
./bin/stop.sh
```
