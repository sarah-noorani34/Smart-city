# Docker Setup Guide — Smart City DBMS

## Prerequisites (Intel Mac)

Install Docker Desktop:
1. Go to https://www.docker.com/products/docker-desktop/
2. Download **Docker Desktop for Mac (Intel Chip)**
3. Open the `.dmg`, drag Docker to Applications, launch it
4. Wait for the whale icon in your menu bar to stop animating (Docker is ready)

That's it — Docker Desktop includes everything you need (docker, docker compose, etc.)

---

## One-Command Start

```bash
# 1. Clone the repo
git clone https://github.com/sarah-noorani34/smart-city.git
cd smart-city
git checkout claude/smart-city-traffic-dbms-0rPSA

# 2. Start ALL services (PostgreSQL + MongoDB + pgAdmin + Mongo Express)
docker compose up -d

# 3. Watch the logs (optional — press Ctrl+C to stop watching, containers keep running)
docker compose logs -f
```

PostgreSQL will automatically:
- Create the `smart_city_db` database
- Enable PostGIS
- Create all 20+ tables
- Load all procedures and triggers
- Insert realistic seed data (zones, roads, sensors, vehicles, incidents)

MongoDB will automatically:
- Create all 5 collections with indexes
- Insert sample sensor logs, incident events, GPS tracks, alerts

**First startup takes ~60 seconds.** Subsequent startups take ~10 seconds.

---

## Access the Visual Interfaces

| Interface      | URL                        | Login                              |
|----------------|----------------------------|------------------------------------|
| pgAdmin 4      | http://localhost:5050      | admin@smartcity.local / admin123   |
| Mongo Express  | http://localhost:8081      | admin / admin123                   |

### pgAdmin — Browse the Database
1. Open http://localhost:5050
2. In the left panel: **Servers → Smart City DB** (already pre-configured)
3. Enter password: `smartcity123`
4. Navigate: **smart_city_db → Schemas → public → Tables**
5. Right-click any table → **View/Edit Data → All Rows**

### Mongo Express — Browse MongoDB
1. Open http://localhost:8081
2. Click **smart_city_db** database
3. Click any collection to see documents

---

## Connect via Terminal (psql)

```bash
# Connect to PostgreSQL inside the container
docker exec -it smartcity_postgres psql -U smartcity -d smart_city_db
```

Once connected, try these commands:
```sql
-- List all tables
\dt

-- See all incidents (trigger already fired on seed data)
SELECT incident_id, category, severity, status FROM incident;

-- See auto-created dispatch records (from CRITICAL incident trigger)
SELECT * FROM dispatch;

-- See audit log (trigger created entries automatically)
SELECT table_name, operation, record_id, changed_at FROM audit_log ORDER BY changed_at DESC;

-- See auto-generated violation (from 127.5 km/h seed reading)
SELECT * FROM violation;

-- Test the dispatch procedure manually
UPDATE emergency_unit SET availability_status = 'AVAILABLE';
CALL sp_dispatch_nearest_unit(1, 'AMBULANCE', NULL, NULL, NULL);

-- Test signal optimizer
CALL sp_optimize_signal_timing(1, NULL, NULL);
SELECT signal_id, green_duration_sec, red_duration_sec FROM traffic_signal;

-- Test congestion report
CALL sp_zone_congestion_report();

-- Spatial query: units within 2km of incident
SELECT eu.unit_id, eu.unit_type,
       ROUND(ST_Distance(eu.current_location::geography,
             (SELECT location::geography FROM incident WHERE incident_id=1))::numeric, 0) AS dist_m
FROM emergency_unit eu
WHERE ST_DWithin(eu.current_location::geography,
      (SELECT location::geography FROM incident WHERE incident_id=1), 2000);

-- Temporal query: incident history
SELECT incident_id, status, valid_from, valid_to FROM incident ORDER BY valid_from;

-- Refresh materialized view
REFRESH MATERIALIZED VIEW mv_zone_traffic_summary;
SELECT zone_name, active_incidents, critical_incidents FROM mv_zone_traffic_summary;
```

---

## Connect via Terminal (mongosh)

```bash
# Connect to MongoDB inside the container
docker exec -it smartcity_mongo mongosh smart_city_db
```

Once connected:
```js
// See all collections
show collections

// View sensor logs
db.sensor_logs.find().pretty()

// View incident events
db.incident_events.find().pretty()

// Zone incident aggregation
db.incident_events.aggregate([
  { $group: { _id: "$zone", count: { $sum: 1 } } },
  { $sort: { count: -1 } }
])

// Geospatial query: sensor logs near the incident
db.sensor_logs.aggregate([
  { $geoNear: {
      near: { type: "Point", coordinates: [67.051, 24.873] },
      distanceField: "dist_meters",
      maxDistance: 2000,
      spherical: true
  }},
  { $project: { "sensor_meta.sensor_id":1, speed_kmh:1, dist_meters:1, _id:0 } }
])
```

---

## Demo Sequence for Teacher Presentation

### Step 1 — Verify everything loaded
```bash
docker exec -it smartcity_postgres psql -U smartcity -d smart_city_db \
  -c "SELECT 'Tables' AS check, COUNT(*) FROM information_schema.tables WHERE table_schema='public'
      UNION ALL SELECT 'Triggers', COUNT(*) FROM information_schema.triggers WHERE trigger_schema='public'
      UNION ALL SELECT 'Incidents', COUNT(*) FROM incident
      UNION ALL SELECT 'Dispatch Records', COUNT(*) FROM dispatch
      UNION ALL SELECT 'Violations', COUNT(*) FROM violation
      UNION ALL SELECT 'Audit Entries', COUNT(*) FROM audit_log;"
```

### Step 2 — Show trigger firing live
```bash
docker exec -it smartcity_postgres psql -U smartcity -d smart_city_db
```
```sql
-- Insert a new CRITICAL incident and watch the trigger fire
INSERT INTO incident (category, severity, status, location, zone_id, reported_by, description)
VALUES ('EMERGENCY_EVENT','CRITICAL','REPORTED',
        ST_GeomFromText('POINT(67.062 24.880)',4326), 1, 2,
        'Gas leak detected near residential area — evacuation needed');

-- Immediately check results
SELECT * FROM dispatch ORDER BY dispatch_time DESC LIMIT 3;
SELECT signal_id, current_phase FROM traffic_signal;
SELECT table_name, operation, record_id FROM audit_log ORDER BY changed_at DESC LIMIT 5;
```

### Step 3 — Show EXPLAIN query optimization
```sql
EXPLAIN (ANALYZE, FORMAT TEXT)
SELECT i.incident_id, i.severity, z.zone_name, COUNT(d.dispatch_id) AS units
FROM incident i
JOIN zone z ON z.zone_id = i.zone_id
LEFT JOIN dispatch d ON d.incident_id = i.incident_id
WHERE i.severity IN ('HIGH','CRITICAL') AND i.valid_to = 'infinity'
GROUP BY i.incident_id, i.severity, z.zone_name;
```

---

## Stop / Reset Commands

```bash
# Stop containers (data is preserved)
docker compose down

# Start again (loads from saved data — fast)
docker compose up -d

# FULL RESET — wipes ALL data and reloads from scratch
docker compose down -v
docker compose up -d

# Restart just PostgreSQL
docker compose restart db

# See container status
docker compose ps
```

---

## File Structure

```
smart-city/
├── docker-compose.yml              ← Main Docker config
├── .env                            ← Passwords and config
├── docker/
│   ├── postgres/
│   │   └── init/                   ← Auto-run SQL files (in order)
│   │       ├── 01_extensions.sql   ← Enable PostGIS
│   │       ├── 02_schema.sql       ← All tables + indexes
│   │       ├── 03_plsql.sql        ← Procedures + triggers
│   │       ├── 04_seed_data.sql    ← Test data
│   │       └── 05_matview.sql      ← Materialized view
│   ├── mongo/
│   │   └── init/
│   │       └── 01_collections.js   ← MongoDB collections + seed data
│   └── pgadmin/
│       └── servers.json            ← Pre-configured DB connection
└── [all project .sql/.js/.md files]
```
