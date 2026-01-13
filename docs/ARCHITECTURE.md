# Streambased Architecture

This document describes how Streambased components integrate to provide unified access to streaming and historical data.

## System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              APPLICATIONS                                    │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │  REST / UI   │  │ Spark/Trino  │  │ Kafka Apps   │  │  Data Science │    │
│  │ (Slipstream) │  │ (Iceberg)    │  │ (Consumers)  │  │  (Notebooks)  │    │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘    │
└─────────┼─────────────────┼─────────────────┼─────────────────┼────────────┘
          │                 │                 │                 │
          ▼                 │                 │                 │
┌─────────────────────────────────────────────────────────────────────────────┐
│                          STREAMBASED LAYER                                   │
│                                                                              │
│  ┌─────────────────┐                                                        │
│  │   HyperStream   │    REST Gateway for UI clients                         │
│  │     :9088       │    • SQL via REST API                                  │
│  │                 │    • Index acceleration                                │
│  └────────┬────────┘    • SQL rewriting                                     │
│           │                                                                  │
│           ▼                                                                  │
│  ┌─────────────────┐                                                        │
│  │  Spark Cluster  │    Iceberg client for HyperStream                      │
│  │  (spark-iceberg)│                                                        │
│  │  :15002         │                                                        │
│  └────────┬────────┘                                                        │
│           │                 │                                                │
│           └────────┬────────┘                                                │
│                    │                                   │                     │
│                    ▼                                   ▼                     │
│  ┌─────────────────────────────┐    ┌─────────────────────────────┐         │
│  │           ISK               │    │           KSI               │         │
│  │  (Iceberg Service for Kafka)│    │  (Kafka Service for Iceberg)│         │
│  │                             │    │                             │         │
│  │  Iceberg REST Catalog:11001 │    │  Kafka Protocol :9192       │         │
│  │  S3 API :11000              │    │                             │         │
│  │                             │    │  Merged view for Kafka      │         │
│  │  Exposes 3 views:           │    │  clients                    │         │
│  │  • isk.hotset.*             │    │                             │         │
│  │  • direct.coldset.*         │    │  Zero client changes        │         │
│  │  • isk.merged.*             │    │  required                   │         │
│  └────────────┬────────────────┘    └─────────────┬───────────────┘         │
│               │                                   │                          │
│               └─────────────┬─────────────────────┘                          │
│                             │                                                │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                         Slipstream                                   │    │
│  │                   Configuration Service :3000                        │    │
│  │            Coordinates cluster settings across components            │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┴─────────────────────┐
        │                                           │
        ▼                                           ▼
┌───────────────────────────────┐   ┌───────────────────────────────┐
│           HOTSET              │   │          COLDSET              │
│                               │   │                               │
│  ┌─────────────────────────┐  │   │  ┌─────────────────────────┐  │
│  │        Kafka            │  │   │  │   Iceberg Catalog       │  │
│  │   Broker :9092          │  │   │  │   (REST) :8181          │  │
│  └─────────────────────────┘  │   │  └─────────────────────────┘  │
│                               │   │                               │
│  ┌─────────────────────────┐  │   │  ┌─────────────────────────┐  │
│  │   Schema Registry       │  │   │  │   Object Storage        │  │
│  │       :8081             │  │   │  │   (MinIO/S3) :9000      │  │
│  └─────────────────────────┘  │   │  └─────────────────────────┘  │
│                               │   │                               │
│  Recent data (days/weeks)     │   │  Historical (months/years)    │
└───────────────────────────────┘   └───────────────────────────────┘
```

## Component Details

### ISK (Iceberg Service for Kafka)

**Purpose**: Exposes all three data views (hotset, coldset, merged) as Iceberg-compatible tables.

**Interfaces**:
- **Iceberg REST Catalog** (port 11001) - Standard Iceberg catalog API
- **S3-compatible endpoint** (port 11000) - Serves data as Parquet files

**Three views provided**:

| View | Source | How it works |
|------|--------|--------------|
| `isk.hotset.*` | Kafka | Fetched at runtime from Kafka topics, projected as Iceberg tables |
| `direct.coldset.*` | Iceberg | Proxied to upstream Iceberg tables on object storage |
| `isk.merged.*` | Both | Seamlessly unifies hotset and coldset into single view |

Iceberg clients (Spark, Trino, Snowflake, etc.) connect directly to ISK.

**Data flow for hotset query**:
1. Spark/Trino queries `isk.hotset.transactions`
2. ISK receives catalog request via REST
3. ISK reads from Kafka topic `transactions`
4. Data is returned in Parquet format via S3 API
5. Query engine processes as if reading from Iceberg

**Key environment variables**:
```
ISK_COLDSET_CLIENT_URI=http://rest:8181/        # Iceberg catalog for coldset
ISK_COLDSET_CLIENT_S3_ENDPOINT=http://minio:9000/
ISK_CONFIG_SERVICE_URL=http://slipstream:3000/api/internal/cluster-config
```

### KSI (Kafka Service for Iceberg)

**Purpose**: The inverse of ISK - provides the **merged view** through the Kafka protocol.

**Interface**: Kafka protocol (port 9192) - drop-in replacement for Kafka bootstrap servers

**How it works**:
1. Kafka consumer connects to KSI at `ksi:9192` (instead of `kafka1:9092`)
2. Consumer requests offset 0 (start from beginning)
3. KSI checks: is offset 0 still in Kafka?
4. If not in Kafka → reads from Iceberg coldset table
5. If in Kafka → forwards to Kafka cluster
6. Seamlessly handles the transition as consumer traverses from cold to hot data

**Key difference from ISK**:
- ISK: Iceberg clients access Kafka data
- KSI: Kafka clients access Iceberg data
- Both provide unified hot+cold access, just through different protocols

**Configuration**:
```
KSI_BOOTSTRAP_SERVERS=kafka1:9092
KSI_COLD_STORAGE_TYPE=spark-connect
KSI_SPARK_CONNECT_URL=sc://spark-iceberg:15002
KSI_ICEBERG_NAMESPACE=coldset
```

### HyperStream

**Purpose**: REST API gateway for UI and HTTP clients with query acceleration features.

**Interface**: HTTP REST API (port 9088)

**How it works**:
1. Slipstream UI (or other HTTP client) sends SQL query via REST
2. HyperStream optionally rewrites SQL to use index tables for acceleration
3. HyperStream routes query via Spark Connect to Spark cluster
4. Spark cluster queries ISK as an Iceberg client
5. Results return through the chain to the HTTP client

**Key capabilities**:
- **REST query endpoint** (`POST /api/query`) - Execute SQL queries via HTTP
- **Index acceleration** - Creates reverse-lookup / bloom-style indexes for Iceberg tables
- **SQL rewriting** - Automatically rewrites queries to use index tables (via additional joins) for partition pruning

**Additional endpoints**:
- `POST /api/index` - Create or update index tables
- `GET /api/schema` - Retrieve schema metadata
- `POST /api/enrich` - Enrich and validate SQL (apply index rewrites)

**Example queries**:
```sql
-- Count records in each tier
SELECT 'hotset', COUNT(*) FROM isk.hotset.transactions
UNION
SELECT 'coldset', COUNT(*) FROM direct.coldset.transactions
UNION
SELECT 'merged', COUNT(*) FROM isk.merged.transactions;
```

### Slipstream

**Purpose**: Centralized configuration management.

**Interface**: HTTP API (port 3000)

Provides cluster configuration to ISK and other components, including:
- Kafka bootstrap servers
- Schema Registry URL
- Authentication credentials

## Data Flow Scenarios

### Scenario 1: SQL Query (Spark/Trino)

```
User                    Spark                ISK           Kafka
 │                        │                       │                   │
 │──SELECT * FROM         │                       │                   │
 │  isk.hotset.txns───────→                       │                   │
 │                        │──catalog request──────→                   │
 │                        │←─table metadata───────│                   │
 │                        │──S3 GET (data)────────→                   │
 │                        │                       │──read topic───────→
 │                        │                       │←─records──────────│
 │                        │←─parquet data─────────│                   │
 │←─query results─────────│                       │                   │
```

### Scenario 2: Kafka Consumer via KSI

```
Consumer                 KSI                  Kafka              Iceberg
 │                        │                     │                   │
 │──subscribe(topic)──────→                     │                   │
 │──poll(offset=0)────────→                     │                   │
 │                        │ (offset 0 < Kafka   │                   │
 │                        │  earliest offset)   │                   │
 │                        │──read coldset table─────────────────────→
 │                        │←─historical records─────────────────────│
 │←─records (from cold)───│                     │                   │
 │                        │                     │                   │
 │──poll(offset=N)────────→                     │                   │
 │                        │ (offset N >= Kafka  │                   │
 │                        │  earliest offset)   │                   │
 │                        │──fetch(offset=N)────→                   │
 │                        │←─records────────────│                   │
 │←─records (from hot)────│                     │                   │
```

### Scenario 3: Unified Merged Query

```
User                    Spark               ISK         Iceberg REST
 │                        │                       │                   │
 │──SELECT * FROM         │                       │                   │
 │  isk.merged.txns───────→                       │                   │
 │                        │                       │                   │
 │                        │ (Query plan: UNION   │                   │
 │                        │  hotset + coldset)   │                   │
 │                        │                       │                   │
 │                        │──query hotset────────→ (via ISK)│
 │                        │──query coldset───────────────────────────→
 │                        │←─hot records─────────│                   │
 │                        │←─cold records────────────────────────────│
 │                        │ (merge + dedupe)     │                   │
 │←─unified results───────│                       │                   │
```

## Port Reference

| Component | Port | Protocol | Purpose |
|-----------|------|----------|---------|
| Kafka | 9092 | Kafka | Message broker |
| Schema Registry | 8081 | HTTP | Avro schema management |
| ISK S3 | 11000 | S3/HTTP | Kafka data as Parquet |
| ISK Catalog | 11001 | Iceberg REST | Table metadata for all 3 views |
| KSI | 9192 | Kafka | Merged view via Kafka protocol |
| Spark Connect | 15002 | gRPC | Spark SQL access |
| Iceberg REST Catalog | 8181 | HTTP | Coldset table metadata |
| MinIO | 9000 | S3 | Object storage |
| MinIO Console | 9001 | HTTP | Storage UI |
| Slipstream | 3000 | HTTP | Configuration + Web UI |
| HyperStream | 9088 | HTTP | REST API gateway for SQL queries |

## Related Documentation

- [Streambased Overview](./STREAMBASED_OVERVIEW.md) - Product introduction
- [Demo Quickstart](./QUICKSTART.md) - Hands-on walkthrough
