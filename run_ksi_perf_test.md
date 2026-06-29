# KSI Reordered Performance Test Runbook

This document describes how to run every KSI reordered performance test in this repository, what each spec measures, and which variables tune the run.

Run commands from the repository root unless a command explicitly.


## What The Perf Test Measures

All KSI reordered performance specs use the same Scala benchmark in `tests/ksi/reordered_perf_test.scala`.

Each run consumes and reports three cases:

1. `reordered_perf_customers_ordered` through KSI as an already sorted reordered topic.
2. `reordered_perf_customers` through KSI as the normal reordered topic.
3. `reordered_perf_customers_kafka` directly from Kafka as a comparison baseline.

The reordered KSI groups use:

```yaml
orderBy: "kafka_timestamp ASC"
```

The benchmark prints one summary per case and a final comparison table with records/sec, elapsed time, poll counts, records per poll batch, and ratios against Kafka.

You can run all three cases or select only the cases you need with `REORDERED_PERF_CASES`.

For split reordered perf datasets, `REORDERED_PERF_CASES` is also honored during full setup. For example, `REORDERED_PERF_CASES=baseline,kafka` loads only `setup-baseline.json` and `setup-kafka.json`; it skips `setup-ordered.json`.

## Spec Matrix

| Spec | Full setup command | Rerun existing data | KSI source | Preload |
| --- | --- | --- | --- | --- |
| `ksi_reordered_perf` | `./bin/start.sh ksi_reordered_perf` | `./tests/ksi_reordered_perf/run.sh` | `direct.coldset` | Off |
| `ksi_reordered_perf_preload` | `./bin/start.sh ksi_reordered_perf_preload` | `./tests/ksi_reordered_perf_preload/run.sh` | `direct.coldset` | On |
| `ksi_reordered_perf_streaming_reader` | `./bin/start.sh ksi_reordered_perf_streaming_reader` | `./tests/ksi_reordered_perf_streaming_reader/run.sh` | `direct.coldset` | On, plus streaming cursor |
| `ksi_isk_hot_topic_reordering` | `./bin/start.sh ksi_isk_hot_topic_reordering` | `./tests/ksi_isk_hot_topic_reordering/run.sh` | `isk.hotset` | Off |
| `ksi_isk_hot_topic_reordering_preload` | `./bin/start.sh ksi_isk_hot_topic_reordering_preload` | `./tests/ksi_isk_hot_topic_reordering_preload/run.sh` | `isk.hotset` | On |
| `ksi_isk_hot_topic_reordering_streaming_reader` | `./bin/start.sh ksi_isk_hot_topic_reordering_streaming_reader` | `./tests/ksi_isk_hot_topic_reordering_streaming_reader/run.sh` | `isk.hotset` | On, plus streaming cursor |

Use `./bin/start.sh ...` when data is not loaded yet. Use the test runner directly when data is already loaded and you only want to recreate KSI and rerun consumers.

## Quick Run: Direct Coldset Streaming Reader

Run the direct.coldset streaming-reader spec from the repository root:

```bash
cd /Users/lemanhcuong/Project/Java/breakstream
```

Full setup, including data load:

```bash
REORDERED_PERF_TARGET_RECORDS=1990000 \
REORDERED_PERF_KSI_MAX_POLL_RECORDS=100000 \
./bin/start.sh ksi_reordered_perf_streaming_reader
```

Rerun against existing loaded data:

```bash
REORDERED_PERF_CASES=baseline,kafka \
REORDERED_PERF_TARGET_RECORDS=1990000 \
REORDERED_PERF_KSI_MAX_POLL_RECORDS=100000 \
./tests/ksi_reordered_perf_streaming_reader/run.sh
```

Tune cursor/prefetch batch size:

```bash
KSI_BATCH_SIZE=50000 \
KSI_PREFETCH_TRIGGER_THRESHOLD=3 \
REORDERED_PERF_CASES=baseline,kafka \
REORDERED_PERF_TARGET_RECORDS=1990000 \
./tests/ksi_reordered_perf_streaming_reader/run.sh
```

This runner recreates `ksi` with `direct.coldset`, preload enabled, and `KSI_STREAMING_READER_ENABLED=true`.

## Full Setup Runs

Cold-storage KSI:

```bash
./bin/start.sh ksi_reordered_perf
```

Cold-storage KSI with preload:

```bash
./bin/start.sh ksi_reordered_perf_preload
```

Cold-storage KSI with preload and streaming reader:

```bash
./bin/start.sh ksi_reordered_perf_streaming_reader
```

ISK hotset KSI:

```bash
./bin/start.sh ksi_isk_hot_topic_reordering
```

ISK hotset KSI with preload:

```bash
./bin/start.sh ksi_isk_hot_topic_reordering_preload
```

ISK hotset KSI with preload and streaming reader:

```bash
./bin/start.sh ksi_isk_hot_topic_reordering_streaming_reader
```

The cold-storage specs load `datasets/ksi_reordered_perf`, copy `reordered_perf_customers` and `reordered_perf_customers_ordered` from `isk.hotset` to `direct.coldset`, then drain those two KSI topics from Kafka.

The ISK-hot specs load `datasets/ksi_reordered_perf_isk_hot` and do not run a coldset migration. KSI reads directly from:

```bash
KSI_SPARK_CATALOG_NAME=isk
KSI_ICEBERG_NAMESPACE=hotset
```

## Rerun Existing Data

Cold-storage KSI:

```bash
./tests/ksi_reordered_perf/run.sh
```

Cold-storage KSI with preload:

```bash
./tests/ksi_reordered_perf_preload/run.sh
```

Cold-storage KSI with preload and streaming reader:

```bash
./tests/ksi_reordered_perf_streaming_reader/run.sh
```

ISK hotset KSI:

```bash
./tests/ksi_isk_hot_topic_reordering/run.sh
```

ISK hotset KSI with preload:

```bash
./tests/ksi_isk_hot_topic_reordering_preload/run.sh
```

ISK hotset KSI with preload and streaming reader:

```bash
./tests/ksi_isk_hot_topic_reordering_streaming_reader/run.sh
```

Each runner rewrites `environment/ksi-reordered-groups.yaml`, recreates the `ksi` container, deletes the benchmark consumer groups, and starts consuming from earliest offsets.

## Common Benchmark Variables

These variables tune the Scala consumer benchmark. They work on all KSI reordered performance specs.

| Variable | Default | Meaning |
| --- | --- | --- |
| `REORDERED_PERF_TARGET_RECORDS` | `1000000` | Records each benchmark consumer tries to consume before reporting. |
| `REORDERED_PERF_KSI_MAX_POLL_RECORDS` | `50000` | Kafka consumer `max.poll.records` for KSI consumers. |
| `REORDERED_PERF_KAFKA_MAX_POLL_RECORDS` | `200` | Kafka consumer `max.poll.records` for the direct Kafka baseline. |
| `REORDERED_PERF_POLL_TIMEOUT_SECONDS` | `30` | Timeout passed to `KafkaConsumer.poll`. ISK-hot runners default this to `120`. |
| `REORDERED_PERF_EMPTY_POLLS` | `3` | Empty polls allowed before the benchmark stops waiting. |
| `REORDERED_PERF_CASES` | `ordered,baseline,kafka` | Comma-separated cases to run. Use `ordered`, `baseline`, `kafka`, `all`, or concrete topic names. |

Example full run with a larger target and KSI consumer poll size:

```bash
REORDERED_PERF_TARGET_RECORDS=1990000 \
REORDERED_PERF_KSI_MAX_POLL_RECORDS=100000 \
./bin/start.sh ksi_isk_hot_topic_reordering_preload
```

Example quick rerun:

```bash
REORDERED_PERF_TARGET_RECORDS=100000 \
REORDERED_PERF_KSI_MAX_POLL_RECORDS=100000 \
./tests/ksi_isk_hot_topic_reordering/run.sh
```

Example: run only normal reordered KSI plus direct Kafka, skipping the ordered KSI topic:

```bash
REORDERED_PERF_CASES=baseline,kafka \
REORDERED_PERF_TARGET_RECORDS=1990000 \
./tests/ksi_isk_hot_topic_reordering/run.sh
```

The same selector works on full setup:

```bash
REORDERED_PERF_CASES=baseline,kafka \
REORDERED_PERF_TARGET_RECORDS=1990000 \
./bin/start.sh ksi_isk_hot_topic_reordering_streaming_reader
```

This loads only the baseline KSI topic and direct Kafka topic for `ksi_reordered_perf_isk_hot`.

Example: run only the ordered KSI topic plus direct Kafka:

```bash
REORDERED_PERF_CASES=ordered,kafka \
REORDERED_PERF_TARGET_RECORDS=1990000 \
./tests/ksi_isk_hot_topic_reordering/run.sh
```

Concrete topic names also work:

```bash
REORDERED_PERF_CASES=reordered_perf_customers,reordered_perf_customers_kafka \
./tests/ksi_isk_hot_topic_reordering/run.sh
```

## KSI Read Variables

These variables tune KSI itself, not the benchmark consumer.

| Variable | Default in cold-storage runners | Default in ISK-hot runners | Meaning |
| --- | --- | --- | --- |
| `KSI_BATCH_SIZE` | `10000` from `environment/streambased-docker-compose.part.yaml` | `50000` | Unified KSI batch size. Controls cold-storage fetch size, cache batch size, prefetch batch size, and streaming cursor drain size. |
| `KSI_COLD_STORAGE_TIMEOUT_MS` | `30000` | `120000` | KSI cold-storage read timeout. |
| `KSI_SPARK_CATALOG_NAME` | `direct` | `isk` | Spark catalog KSI queries. |
| `KSI_ICEBERG_NAMESPACE` | `coldset` | `hotset` | Namespace KSI queries. |

Increasing `REORDERED_PERF_KSI_MAX_POLL_RECORDS` does not increase KSI’s internal cold-storage read cap. Raise `KSI_BATCH_SIZE` too if the KSI batch size is the bottleneck.

Example ISK-hot preload rerun with larger KSI batches:

```bash
KSI_BATCH_SIZE=100000 \
REORDERED_PERF_KSI_MAX_POLL_RECORDS=100000 \
./tests/ksi_isk_hot_topic_reordering_preload/run.sh
```

## Preload Variables

Preload means KSI record cache plus prefetch. These variables are applied by:

- `environment/docker-compose.preload.yaml`
- `tests/ksi/reordered_perf_preload_fresh.sh`
- `tests/ksi/isk_hot_reordered_perf_preload_fresh.sh`

| Variable | Default in preload runners | Meaning |
| --- | --- | --- |
| `KSI_RECORD_CACHE_ENABLED` | `true` | Master switch for record cache and prefetch. |
| `KSI_RECORD_CACHE_MAX_BYTES` | `536870912` | Max cache size in bytes. |
| `KSI_PREFETCH_ENABLED` | `true` | Enables async prefetch after cache hits. |
| `KSI_PREFETCH_BATCH_COUNT` | `5` | Number of future batches to warm. |
| `KSI_BATCH_SIZE` | `10000` for cold-storage preload, `50000` for ISK-hot preload | Unified cold-storage, cache, and prefetch batch size. |
| `KSI_PREFETCH_TRIGGER_THRESHOLD` | `2` | Number of sequential cache hits before prefetch starts. |

Example preload rerun with larger prefetch batches:

```bash
REORDERED_PERF_TARGET_RECORDS=1990000 \
REORDERED_PERF_KSI_MAX_POLL_RECORDS=100000 \
KSI_BATCH_SIZE=50000 \
KSI_PREFETCH_TRIGGER_THRESHOLD=2 \
./tests/ksi_isk_hot_topic_reordering_preload/run.sh
```

## Streaming Reader Variables

The streaming reader changes only the reordered read path. It sits below cache and prefetch, so streaming-reader specs also enable preload.

The direct.coldset streaming-reader spec applies:

- `environment/docker-compose.preload.yaml`
- `environment/docker-compose.streaming-reader.yaml`
- `tests/ksi/reordered_perf_streaming_reader_fresh.sh`

The ISK-hot streaming-reader spec applies:

- `environment/docker-compose.isk-hot.yaml`
- `environment/docker-compose.preload.yaml`
- `environment/docker-compose.streaming-reader.yaml`
- `tests/ksi/isk_hot_reordered_perf_streaming_reader_fresh.sh`

| Variable | Default in streaming-reader runner | Meaning |
| --- | --- | --- |
| `KSI_STREAMING_READER_ENABLED` | `true` | Enables the held-open Spark cursor for reordered reads. |
| `KSI_RECORD_CACHE_MAX_BYTES` | `104857600000` | Larger cache cap for large cursor batches. |
| `KSI_PREFETCH_BATCH_COUNT` | `4` | Number of future cursor/cache batches to warm. |
| `KSI_BATCH_SIZE` | `100000` | Unified cold-storage, cursor drain, cache, and prefetch batch size. |
| `KSI_PREFETCH_TRIGGER_THRESHOLD` | `2` | Number of sequential cache hits before prefetch starts. |

Full setup:

```bash
REORDERED_PERF_TARGET_RECORDS=1990000 \
REORDERED_PERF_KSI_MAX_POLL_RECORDS=100000 \
./bin/start.sh ksi_reordered_perf_streaming_reader
```

Rerun existing data:

```bash
REORDERED_PERF_CASES=baseline,kafka \
REORDERED_PERF_TARGET_RECORDS=1990000 \
REORDERED_PERF_KSI_MAX_POLL_RECORDS=100000 \
./tests/ksi_reordered_perf_streaming_reader/run.sh
```

Override cursor batch size:

```bash
KSI_BATCH_SIZE=50000 \
KSI_PREFETCH_TRIGGER_THRESHOLD=3 \
REORDERED_PERF_CASES=baseline,kafka \
./tests/ksi_reordered_perf_streaming_reader/run.sh
```

## Compare Preload Speedup

Cold-storage comparison:

```bash
./tests/ksi_reordered_perf/run.sh
./tests/ksi_reordered_perf_preload/run.sh
./tests/ksi_reordered_perf_streaming_reader/run.sh
```

Compare:

- `ksi-baseline` vs `ksi-preload-baseline`
- `ksi-ordered-coldset` vs `ksi-preload-ordered`
- `ksi-preload-baseline` vs `ksi-coldset-streaming-baseline`
- `ksi-preload-ordered` vs `ksi-coldset-streaming-ordered`

ISK-hot comparison:

```bash
./tests/ksi_isk_hot_topic_reordering/run.sh
./tests/ksi_isk_hot_topic_reordering_preload/run.sh
```

Compare:

- `ksi-hotset-baseline` vs `ksi-hotset-preload-baseline`
- `ksi-hotset-ordered` vs `ksi-hotset-preload-ordered`

ISK-hot streaming-reader comparison:

```bash
./tests/ksi_isk_hot_topic_reordering_preload/run.sh
./tests/ksi_isk_hot_topic_reordering_streaming_reader/run.sh
```

Compare:

- `ksi-hotset-preload-baseline` vs `ksi-hotset-streaming-baseline`
- `ksi-hotset-preload-ordered` vs `ksi-hotset-streaming-ordered`

## Post Setup

To rerun only the staged post-setup script, run it from `environment/`:

```bash
cd /Users/lemanhcuong/Project/Java/breakstream/environment
./shadowtraffic/post_setup.sh
```

For the cold-storage perf dataset, this copies the reordered perf hotsets to `direct.coldset` and drains the KSI topics from Kafka.

## Spark Shell For Inspection

Run:

```bash
cd /Users/lemanhcuong/Project/Java/breakstream/environment
docker --log-level ERROR compose exec spark-iceberg spark-shell --driver-memory 8g --conf spark.ui.enabled=false
```

Useful checks:

```scala
spark.sql("SHOW TABLES IN isk.hotset").show(false)
spark.sql("SHOW TABLES IN direct.coldset").show(false)
spark.sql("SELECT COUNT(*) FROM isk.hotset.reordered_perf_customers").show(false)
spark.sql("SELECT COUNT(*) FROM isk.hotset.reordered_perf_customers_ordered").show(false)
spark.sql("SELECT COUNT(*) FROM direct.coldset.reordered_perf_customers").show(false)
spark.sql("SELECT COUNT(*) FROM direct.coldset.reordered_perf_customers_ordered").show(false)
```

## Verify Preload Or Streaming Reader Is Actually Enabled

After a preload runner recreates KSI, check logs:

```bash
cd /Users/lemanhcuong/Project/Java/breakstream/environment
docker --log-level ERROR compose logs --tail=200 ksi
```

Look for startup lines showing `recordCacheEnabled=true`, `prefetchEnabled=true`, and a created `MemoryRecordsCache`. During consumption, grep for cache and prefetch activity:

```bash
docker --log-level ERROR compose logs ksi | rg "CACHE|PREFETCH|RecordCache|MemoryRecordsCache"
```

For streaming-reader runs, also check:

```bash
docker --log-level ERROR compose logs ksi | rg "STREAMING|streaming reader|StreamingColdStorageReader"
```

Expected signs are startup lines showing `streamingReaderEnabled=true` and runtime lines like `opening ordered cursor` followed by multiple `drained ... rows` entries.
