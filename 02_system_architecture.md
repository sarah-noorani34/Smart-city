# 2. System Architecture

## Components

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     Smart City Traffic & Emergency Hub                  │
├───────────────┬──────────────────┬──────────────────┬───────────────────┤
│  IoT Layer    │  Application     │  Database Layer  │  Analytics Layer  │
│               │  Services        │                  │                   │
│  - Road       │  - Traffic Mgmt  │  PostgreSQL      │  Query Optimizer  │
│    Sensors    │    Service       │  (Primary RDBMS) │  (EXPLAIN ANALYZE)│
│  - Speed      │  - Emergency     │                  │                   │
│    Cameras    │    Dispatch      │  MongoDB         │  Spatial Engine   │
│  - Signal     │  - Signal Ctrl   │  (Logs/Events)   │  (PostGIS)        │
│    Controllers│  - Route Planner │                  │                   │
│  - GPS Units  │  - Reporting     │  XML Store       │  Temporal Engine  │
│               │                  │  (Config/Data)   │  (Bi-temporal)    │
└───────────────┴──────────────────┴──────────────────┴───────────────────┘
```

## Databases Used and Purpose

| Database        | Type              | Purpose                                                        |
|-----------------|-------------------|----------------------------------------------------------------|
| PostgreSQL      | Relational/OR     | Core entities: vehicles, roads, signals, incidents, persons    |
| PostGIS         | Spatial Extension | Geospatial road/zone/incident data (point, linestring, polygon)|
| MongoDB         | NoSQL Document    | High-volume sensor logs, event streams, audit trails           |
| XML (pg/xmltype)| Semi-structured   | Emergency dispatch configs, signal timing plans, reports       |
| Distributed PG  | Distributed RDBMS | Horizontal fragmentation across 4 city-zone nodes              |

## System Data Flow

```
IoT Sensors  →  Kafka Stream  →  PostgreSQL (write)  →  Triggers/Procedures
                     └──────────→  MongoDB (event log)
                                         ↓
                           Reports / Dashboard / APIs
```
