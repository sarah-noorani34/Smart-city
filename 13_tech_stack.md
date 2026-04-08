# 13. Tech Stack

| Layer               | Technology                          | Purpose                                          |
|---------------------|-------------------------------------|--------------------------------------------------|
| Primary RDBMS       | PostgreSQL 16                       | Core relational data, PL/pgSQL, partitioning     |
| Spatial Extension   | PostGIS 3.4                         | Geometry types, spatial indexes, geo queries     |
| Distributed RDBMS   | Citus (pg extension)                | Horizontal sharding across zone nodes            |
| Replication         | pg_logical                          | Logical replication for reference tables         |
| NoSQL               | MongoDB 7 (time-series collections) | Sensor logs, GPS tracks, event streams           |
| XML Store           | PostgreSQL xmltype + BaseX          | Dispatch configs, semi-structured docs           |
| Object-Relational   | PostgreSQL composite types, arrays  | address_type, contact_info_type, equipment_list  |
| Query Optimizer     | PostgreSQL CBO + EXPLAIN ANALYZE    | Index selection, partition pruning, mat. views   |
| Scheduling          | pg_cron                             | Materialized view refresh, partition maintenance |
| Streaming           | Apache Kafka                        | IoT sensor data ingestion pipeline               |
| Connection Pool     | PgBouncer                           | Connection pooling for high-concurrency writes   |
| Monitoring          | pg_stat_statements + Prometheus     | Query performance tracking, alerting             |
| Application Layer   | Python 3.12 + FastAPI               | REST APIs for dashboard and dispatch console     |
| ORM                 | SQLAlchemy 2 + GeoAlchemy2          | Model mapping with spatial support               |
| Cache               | Redis 7                             | Zone traffic summary caching (5-min TTL)         |
| Container           | Docker + Docker Compose             | Local dev environment                            |
| Orchestration       | Kubernetes                          | Production deployment, zone node scaling         |
