# Smart City Traffic and Emergency Management System
### Advanced DBMS Project — Complete Implementation

A fully integrated database system covering **all advanced DBMS concepts** in a single cohesive project.

---

## Project Structure

| File | Section | Contents |
|------|---------|----------|
| `01_problem_statement.md` | Problem Statement | Goals and scope |
| `02_system_architecture.md` | System Architecture | Components, databases, data flow |
| `03_eer_design.md` | EER Design | Entities, relationships, specialization/generalization |
| `04_relational_schema.sql` | Relational Schema | Full PostgreSQL DDL with PK/FK, enums, partitioning |
| `05_mongodb_design.js` | MongoDB Design | 5 collections with sample documents and indexes |
| `06_distributed_db_design.md` | Distributed DB | Fragmentation, replication, allocation strategy |
| `07_plsql_code.sql` | PL/SQL Code | 2 procedures (with cursors) + 2 triggers |
| `08_xml_design.xml` | XML Design | XSD schema, sample document, XPath + XQuery |
| `09_spatial_temporal.sql` | Spatial & Temporal | PostGIS queries + bi-temporal incident versioning |
| `10_query_optimization.sql` | Query Optimization | Before/after with EXPLAIN, indexes, mat. views |
| `11_sample_queries.sql` | Sample Queries | 3 SQL + 2 MongoDB aggregation queries |
| `12_concurrency_control.md` | Concurrency Control | MVCC, 2PL, SELECT FOR UPDATE SKIP LOCKED |
| `13_tech_stack.md` | Tech Stack | Full technology list |

---

## DBMS Concepts Covered

| Concept | Implementation |
|---------|---------------|
| EER Model | Superclass/subclass with disjoint-total and overlapping-partial specializations |
| Relational Schema | PostgreSQL DDL — 20+ tables, enums, FK constraints, CHECK constraints |
| Object-Relational | Composite types (`address_type`, `contact_info_type`), array columns |
| PL/SQL | 3 stored procedures (with explicit cursors, OUT params) + 2 triggers |
| Distributed DB | Horizontal + vertical fragmentation; full and partial replication; zone-based allocation |
| Query Optimization | CTE rewrite, partial indexes, covering indexes, materialized views, EXPLAIN ANALYZE |
| XML | XSD schema, sample dispatch record XML, XPath + XQuery + PostgreSQL xmltype storage |
| NoSQL | MongoDB time-series, geospatial, aggregation pipelines |
| Semi-structured | XML config docs + MongoDB flexible event documents |
| Temporal DB | Bi-temporal (valid time + transaction time) on incident table |
| Spatial DB | PostGIS POINT/LINESTRING/POLYGON, ST_DWithin, ST_Distance, ST_Within, GiST indexes |
| Concurrency Control | MVCC explanation, `SELECT FOR UPDATE SKIP LOCKED`, isolation levels, deadlock prevention |

---

## Key Entities

- **Person** → Driver, Emergency Responder, Traffic Officer *(overlapping-partial)*
- **Vehicle** → Private, Public, Emergency *(disjoint-total)*
- **Incident** → Accident, Congestion, Emergency Event *(disjoint-total)*
- Road, Intersection, Traffic Signal, Sensor, Zone, Emergency Unit, Dispatch, Violation, Route

---

## Running the Schema

```bash
# Prerequisites: PostgreSQL 16 + PostGIS 3.4
psql -U postgres -c "CREATE DATABASE smart_city_db;"
psql -U postgres -d smart_city_db -f 04_relational_schema.sql
psql -U postgres -d smart_city_db -f 07_plsql_code.sql
psql -U postgres -d smart_city_db -f 09_spatial_temporal.sql
psql -U postgres -d smart_city_db -f 10_query_optimization.sql
psql -U postgres -d smart_city_db -f 11_sample_queries.sql

# MongoDB
mongosh smart_city_db --file 05_mongodb_design.js
```
