# CDC Demo

An interactive demonstration of how Streambased I.S.K. handles Change Data Capture (CDC) streams natively — no custom ETL, no duplicate rows, no ghost records.

## What it shows

A CDC stream is a Kafka topic where each message carries a Debezium envelope: an operation type (`c`/`u`/`d`) and before/after payloads. Without CDC-aware processing, querying such a topic as a table produces duplicates for updated records and stale rows for deleted ones.

This demo walks through three capabilities:

1. **Envelope unwrapping** — I.S.K. exposes the CDC topic as a clean Iceberg table. The `before` and `after` fields are transparent; queries see the current-state payload columns plus `__op`, the operation of the latest event for the key.

2. **CDC deduplication** — Background traffic continuously updates existing orders (PENDING → SHIPPED). The hotset always shows one row per order key at its latest state. `COUNT(*) == COUNT(DISTINCT OrderID)` at all times.

3. **Atomic coldset roll** — A single call to Hyperstream (`POST /api/union/roll`) seals the `orders` topic and merges its CDC records into the Iceberg coldset by key in one commit: existing rows are updated, new ones inserted, and deletes are kept as rows with `__op = 'd'`. The `isk.union.orders` view presents the coldset plus the not yet rolled hotset as one table at every point.

## Data model

Single topic: **`orders`** (Debezium CDC envelope, Avro key + value via Schema Registry)

| Phase | What happens |
|-------|-------------|
| Setup | 500 CREATE events (orders 1–500, status `PENDING`) loaded into Kafka, then rolled to the Iceberg coldset by a roll call. |
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

- `SHOW DATABASES` — three views: `hotset`, `coldset`, `union`
- `DESCRIBE isk.hotset.orders` — envelope unwrapped; schema shows payload columns (OrderID, CustomerID, Status, Amount), not CDC envelope fields
- Row counts across all three views
- Sample records from the hotset showing SHIPPED status (updates already applied)

### Part 2 — CDC deduplication and updates

- `COUNT(*) vs COUNT(DISTINCT OrderID)` from hotset — both equal, confirming no duplicate rows from updates
- Updated orders in hotset show SHIPPED; same records in coldset still show PENDING (original); union shows SHIPPED (hotset wins)
- Pre-delete count of live orders (`__op <> 'd'`) from `isk.union.orders` recorded

Background stops. 100 DELETE events for orders 1–100 are published to Kafka.

### Part 2b — Delete propagation

- Post-delete live count (`__op <> 'd'`) from `isk.union.orders` — down by ~100 (a few more orders may have arrived since the pre-delete count)
- Each delete stays visible as a row with `__op = 'd'`; the original PENDING rows still exist in the coldset but the union view hides them behind the newer delete rows

### Part 3 — Atomic roll to coldset

One call to Hyperstream rolls the orders topic into `direct.coldset.orders`:

```bash
curl -u sbpk_12345678:sbsk_12345678 -H 'content-type: application/json' \
  -d '{"table":"orders"}' http://localhost:9088/api/union/roll
```

The roll seals the topic at its current end, merges the sealed CDC records into the coldset on the Kafka key in one Iceberg commit, and acknowledges the roll. The helper `bin/lib/union_roll.sh` wraps the call.

After the roll:
- Orders 1–100: kept in the coldset as rows with `__op = 'd'`, excluded from the live count
- Orders 101–500: updated in the coldset (PENDING → SHIPPED)
- Orders 1001+: inserted into the coldset
- The union view stays correct throughout; straight after the roll the hotset holds only the unrolled CDC window

## Explore further

After the demo the environment stays running. To inspect directly:

```bash
cd environment
docker compose exec -it spark-iceberg spark-shell

# Inside spark-shell:
spark.sql("SELECT * FROM isk.union.orders LIMIT 20").show()
spark.sql("SELECT * FROM isk.union.orders WHERE __op = 'd'").show()
spark.sql("SELECT Status, COUNT(*) FROM direct.coldset.orders GROUP BY Status").show()
```

Stop the environment when done:

```bash
./bin/stop.sh
```
