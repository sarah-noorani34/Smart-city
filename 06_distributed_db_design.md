# 6. Distributed Database Design

## Overview

The city is divided into **4 geographic zones**, each mapped to a dedicated database node.
A global coordinator node handles cross-zone queries and replication management.

```
┌─────────────────────────────────────────────────────────┐
│               Global Coordinator Node (GC)              │
│         [Citus coordinator / pg_logical router]         │
└────────┬───────────┬────────────┬────────────┬──────────┘
         │           │            │            │
    ┌────▼───┐  ┌────▼───┐  ┌────▼───┐  ┌────▼───┐
    │ Node-1  │  │ Node-2  │  │ Node-3  │  │ Node-4  │
    │ NORTH   │  │ SOUTH   │  │ EAST    │  │ WEST    │
    │ Zone DB │  │ Zone DB │  │ Zone DB │  │ Zone DB │
    └─────────┘  └─────────┘  └─────────┘  └─────────┘
```

---

## Fragmentation Strategy

### 1. Horizontal Fragmentation (Primary)

Tables fragmented by `zone_id` — each node stores only rows for its zone.

#### Table: `incident`
```sql
-- Predicate for each fragment
F_INCIDENT_NORTH:  SELECT * FROM incident WHERE zone_id IN (1, 2);
F_INCIDENT_SOUTH:  SELECT * FROM incident WHERE zone_id IN (3, 4);
F_INCIDENT_EAST:   SELECT * FROM incident WHERE zone_id IN (5, 6);
F_INCIDENT_WEST:   SELECT * FROM incident WHERE zone_id IN (7, 8);
```

#### Table: `sensor_reading`
```sql
-- Range fragmented by zone AND time (month)
F_SR_NORTH_2025Q2: SELECT * FROM sensor_reading
                   WHERE sensor_id IN (SELECT sensor_id FROM sensor
                                       JOIN road USING(road_id)
                                       WHERE zone_id IN (1,2))
                   AND reading_time BETWEEN '2025-04-01' AND '2025-06-30';
```

#### Table: `violation`
```sql
F_VIOLATION_NORTH: SELECT * FROM violation
                   WHERE sensor_id IN (
                       SELECT sensor_id FROM sensor s
                       JOIN road r ON s.road_id = r.road_id
                       WHERE r.zone_id IN (1,2));
```

### 2. Vertical Fragmentation (Secondary)

Applied to `vehicle` — hot columns separated for performance.

```
Fragment A (all nodes — frequently accessed):
    vehicle_id, license_plate, category, owner_id

Fragment B (home zone node — less frequent):
    make, model, year, color, registered_at
```

### 3. Derived Horizontal Fragmentation

`dispatch` is fragmented based on `incident.zone_id` to co-locate
dispatch records with their incidents on the same node.

```sql
F_DISPATCH_NORTH: SELECT d.* FROM dispatch d
                  JOIN incident i ON d.incident_id = i.incident_id
                  WHERE i.zone_id IN (1,2);
```

---

## Replication Strategy

| Table              | Strategy                   | Rationale                               |
|--------------------|----------------------------|-----------------------------------------|
| `zone`             | Full replication (4 nodes) | Small lookup table; queried everywhere  |
| `road`             | Full replication (4 nodes) | Routing needs global road data          |
| `traffic_signal`   | Full replication (4 nodes) | Signal coordination across zone borders |
| `emergency_unit`   | Full replication (4 nodes) | Cross-zone dispatch decisions           |
| `person`           | Full replication (4 nodes) | Identity lookup needed globally         |
| `incident`         | Primary + 1 async replica  | High write rate; eventual consistency   |
| `sensor_reading`   | Primary only (partitioned) | Volume too high; locality sufficient    |
| `violation`        | Primary + 1 async replica  | Legal records need backup               |

**Replication technology:** PostgreSQL logical replication (`pg_logical`)
- Publisher: each zone node  
- Subscriber: coordinator + adjacent node (hot-standby)  
- Lag threshold: alert if replication lag > 5 seconds

---

## Allocation Logic

```
Zone Node Assignment:
┌─────────────────┬───────────┬───────────────────────────────────────────┐
│ Node             │ Zones     │ Primary Tables Stored                     │
├─────────────────┼───────────┼───────────────────────────────────────────┤
│ Node-1 (NORTH)  │ 1, 2      │ incident, dispatch, sensor_reading,       │
│                 │           │ violation (North zones only)              │
├─────────────────┼───────────┼───────────────────────────────────────────┤
│ Node-2 (SOUTH)  │ 3, 4      │ incident, dispatch, sensor_reading,       │
│                 │           │ violation (South zones only)              │
├─────────────────┼───────────┼───────────────────────────────────────────┤
│ Node-3 (EAST)   │ 5, 6      │ incident, dispatch, sensor_reading,       │
│                 │           │ violation (East zones only)               │
├─────────────────┼───────────┼───────────────────────────────────────────┤
│ Node-4 (WEST)   │ 7, 8      │ incident, dispatch, sensor_reading,       │
│                 │           │ violation (West zones only)               │
├─────────────────┼───────────┼───────────────────────────────────────────┤
│ All Nodes       │ ALL       │ zone, road, traffic_signal,               │
│ (replicated)    │           │ emergency_unit, person, vehicle (frag A)  │
└─────────────────┴───────────┴───────────────────────────────────────────┘
```

**Cross-zone query handling:**  
The coordinator uses a distributed query plan — pushes filters to nodes,
merges results. Example: "Find all CRITICAL incidents in the city" →
coordinator broadcasts to all 4 nodes, unions results.

**CAP tradeoff:** System chooses CP (Consistency + Partition Tolerance)
for emergency dispatch; AP (Availability + Partition Tolerance)
for sensor log collection (eventual consistency acceptable).
