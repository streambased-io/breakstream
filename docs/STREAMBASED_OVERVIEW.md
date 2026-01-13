# Streambased Platform Overview

Streambased unifies Apache Kafka and Apache Iceberg into a single real-time analytical view using a **zero-copy** approach. It makes Kafka data instantly queryable in Iceberg format without traditional batch data pipelines.

## The Problem

New data arriving in Kafka typically sits idle until batch pipelines transfer it to a data lake for analysis. This creates:

- **Latency**: Hours or days before new data is queryable
- **Pipeline complexity**: ETL jobs, orchestration, failure handling
- **Duplicate data**: Same records in Kafka and data lake
- **Retention limits**: Kafka retains data for days/weeks, analytics needs months/years

## The Streambased Solution

Streambased projects Kafka into Iceberg **at query time** rather than through background copying processes. No batch windows to wait for - data is fresh the moment it lands.

### Tiered Storage Architecture

| Layer | Description                | Storage |
|-------|----------------------------|---------|
| **Hotset** | Recent streaming data      | Kafka topics |
| **Coldset** | Historical data            | Iceberg tables on object storage (S3/MinIO) |
| **Merged** | Unified view of hot + cold | Virtual layer, zero duplication |

Applications query the merged view and transparently receive data from both tiers.

## Core Components

### ISK (Iceberg Service for Kafka)

Exposes all three data views as Iceberg-compatible tables via S3-compatible API (port 11000) and Iceberg REST Catalog (port 11001):

| View | Source | Description |
|------|--------|-------------|
| **Hotset** | Kafka | Fetched at runtime from Kafka topics, projected as Iceberg tables |
| **Coldset** | Iceberg | Proxied to upstream Iceberg tables on object storage |
| **Merged** | Both | Seamlessly unifies Hot and Cold sets into a single view |

Iceberg clients (Spark, Trino, Snowflake, etc.) connect directly to ISK and query data using standard SQL - whether it's live streaming data, historical data, or both combined.

### KSI (Kafka Service for Iceberg)

The inverse of ISK - provides the **merged view** through the Kafka protocol (port 9192):

- Kafka clients connect to KSI instead of the Kafka broker
- KSI transparently fetches from upstream Kafka or Iceberg depending on the requested offset
- Seamlessly handles the switch between sources as consumers traverse from cold to hot data
- **Zero client changes required** - existing Kafka consumers work unchanged

Think of it as: ISK brings Kafka to Iceberg clients, KSI brings Iceberg to Kafka clients.

### HyperStream

REST API gateway for UI and HTTP clients (port 9088):

- **REST API** for executing SQL queries - used by Slipstream UI and other HTTP clients
- **Spark Connect** backend - routes queries to a Spark cluster that connects to ISK as an Iceberg client
- **Index acceleration** - creates reverse-lookup / bloom-style indexes for Iceberg tables
- **SQL rewriting** - automatically rewrites queries to use index tables (via additional joins) for partition pruning and faster scans

### Slipstream

Configuration and management service with web UI. Uses HyperStream to execute SQL queries written in the UI.

## How It Works

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Applications                                    │
│                                                                              │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐                    │
│  │ REST / UI   │     │  Iceberg    │     │   Kafka     │                    │
│  │ (Slipstream │     │  Clients    │     │  Clients    │                    │
│  │  web UI)    │     │ (Spark,     │     │ (Consumers, │                    │
│  │             │     │  Trino...)  │     │  Flink...)  │                    │
│  └──────┬──────┘     └──────┬──────┘     └──────┬──────┘                    │
└─────────┼───────────────────┼───────────────────┼───────────────────────────┘
          │                   │                   │
          ▼                   │                   │
┌───────────────────┐         │                   │
│   HyperStream     │         │                   │
│  (REST Gateway)   │         │                   │
│                   │         │                   │
│ • SQL via REST    │         │                   │
│ • Index accel.    │         │                   │
│ • SQL rewriting   │         │                   │
└─────────┬─────────┘         │                   │
          │                   │                   │
          ▼                   │                   │
┌───────────────────┐         │                   │
│  Spark Cluster    │         │                   │
│ (spark-iceberg)   │         │                   │
│                   │         │                   │
│  Spark Connect    │         │                   │
└─────────┬─────────┘         │                   │
          │                   │                   │
          └─────────┬─────────┘                   │
                    │                             │
                    ▼                             ▼
          ┌─────────────────────┐     ┌─────────────────────┐
          │        ISK          │     │        KSI          │
          │ (Iceberg Service    │     │ (Kafka Service      │
          │    for Kafka)       │     │    for Iceberg)     │
          │                     │     │                     │
          │ Exposes 3 views:    │     │ Merged view via     │
          │ • hotset.*          │     │ Kafka protocol      │
          │ • coldset.*         │     │                     │
          │ • merged.*          │     │                     │
          └─────────┬───────────┘     └──────────┬──────────┘
                    │                            │
                    └──────────┬─────────────────┘
                               │
             ┌─────────────────┴─────────────────┐
             │                                   │
             ▼                                   ▼
     ┌───────────────┐                   ┌───────────────┐
     │    Kafka      │                   │   Iceberg     │
     │   (Hotset)    │                   │  (Coldset)    │
     │               │                   │               │
     │ Recent data   │                   │ Historical    │
     └───────────────┘                   └───────────────┘
```

## Key Benefits

- **Millisecond-level freshness** - No batch windows
- **Standard interfaces** - SQL, Kafka API, Iceberg
- **Zero client changes** for existing Kafka consumers
- **No compaction or snapshot management** overhead
- **Single logical data source** - No duplicate reconciliation
- **Extended retention** without Kafka storage costs

## Use Cases

- **Real-time dashboards** with historical context
- **ML feature stores** requiring both fresh and historical data
- **Regulatory compliance** with long-term data access
- **Consumer replay** beyond Kafka retention limits
- **Cost optimization** - Hot data in Kafka, cold data in object storage

## Related Documentation

- [Architecture Diagram](./ARCHITECTURE.md) - Detailed component interactions
- [Demo Quickstart](./QUICKSTART.md) - Hands-on walkthrough
