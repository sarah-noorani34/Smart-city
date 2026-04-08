-- ============================================================
-- 9. SPATIAL AND TEMPORAL FEATURES
--    Smart City Traffic & Emergency Management System
-- ============================================================

-- ============================================================
-- SPATIAL FEATURES — PostGIS
-- ============================================================

-- All geometry columns use EPSG:4326 (WGS84 lat/lon)
-- Key spatial columns:
--   zone.boundary          GEOMETRY(POLYGON, 4326)
--   road.road_geom         GEOMETRY(LINESTRING, 4326)
--   incident.location      GEOMETRY(POINT, 4326)
--   sensor.location        GEOMETRY(POINT, 4326)
--   intersection.location  GEOMETRY(POINT, 4326)
--   emergency_unit.current_location  GEOMETRY(POINT, 4326)
--   emergency_station.location       GEOMETRY(POINT, 4326)

-- ─── S1: Insert a zone with polygon boundary ────────────────
INSERT INTO zone (zone_name, zone_type, city_region, boundary)
VALUES (
    'CENTRAL_HIGHWAY', 'HIGHWAY', 'CENTRAL',
    ST_GeomFromText(
        'POLYGON((67.04 24.86, 67.06 24.86, 67.06 24.88, 67.04 24.88, 67.04 24.86))',
        4326
    )
);

-- ─── S2: Insert a road with linestring geometry ──────────────
INSERT INTO road (road_name, road_type, speed_limit_kmh, lanes, zone_id, road_geom, length_km)
VALUES (
    'Main Sharea Faisal', 'ARTERIAL', 80, 6, 1,
    ST_GeomFromText('LINESTRING(67.0400 24.8600, 67.0512 24.8732, 67.0622 24.8801)', 4326),
    ST_Length(ST_GeomFromText(
        'LINESTRING(67.0400 24.8600, 67.0512 24.8732, 67.0622 24.8801)', 4326)::geography
    ) / 1000.0
);

-- ─── S3: Find emergency units within 2 km of an incident ────
SELECT
    eu.unit_id,
    eu.unit_type,
    eu.agency_name,
    eu.availability_status,
    ROUND(ST_Distance(
        eu.current_location::geography,
        i.location::geography
    )::numeric, 0) AS dist_meters
FROM emergency_unit eu
CROSS JOIN incident i
WHERE i.incident_id = 4821
  AND eu.availability_status = 'AVAILABLE'
  AND ST_DWithin(
        eu.current_location::geography,
        i.location::geography,
        2000     -- 2 km radius
      )
ORDER BY dist_meters ASC;

-- ─── S4: Find all roads that intersect a congestion zone ────
SELECT
    r.road_id,
    r.road_name,
    r.speed_limit_kmh,
    ST_Length(r.road_geom::geography) / 1000.0 AS length_km
FROM road r
JOIN zone z ON z.zone_name = 'CENTRAL_HIGHWAY'
WHERE ST_Intersects(r.road_geom, z.boundary);

-- ─── S5: Find incidents within a zone polygon ───────────────
SELECT
    i.incident_id,
    i.category,
    i.severity,
    i.incident_time,
    ST_AsText(i.location) AS incident_coords
FROM incident i
JOIN zone z ON z.zone_id = 1
WHERE ST_Within(i.location, z.boundary)
  AND i.status NOT IN ('RESOLVED', 'CLOSED')
ORDER BY i.incident_time DESC;

-- ─── S6: Nearest road to a reported incident ────────────────
SELECT
    r.road_id,
    r.road_name,
    ROUND(ST_Distance(
        r.road_geom::geography,
        ST_GeomFromText('POINT(67.0512 24.8732)', 4326)::geography
    )::numeric, 1) AS dist_meters
FROM road r
ORDER BY dist_meters ASC
LIMIT 1;

-- ─── S7: Traffic density heatmap — sensor points with counts─
SELECT
    ST_AsGeoJSON(s.location)::json AS sensor_geojson,
    COALESCE(AVG(sr.vehicle_count), 0) AS avg_vehicle_count,
    COALESCE(AVG(sr.occupancy_pct), 0) AS avg_occupancy
FROM sensor s
LEFT JOIN sensor_reading sr
       ON sr.sensor_id   = s.sensor_id
      AND sr.reading_time >= NOW() - INTERVAL '1 hour'
WHERE s.sensor_type = 'INDUCTIVE_LOOP'
GROUP BY s.sensor_id, s.location
ORDER BY avg_vehicle_count DESC;

-- ─── S8: Buffer zone around incident — 500m evacuation radius
SELECT
    ST_AsGeoJSON(
        ST_Buffer(i.location::geography, 500)::geometry
    ) AS evacuation_zone_geojson
FROM incident i
WHERE i.incident_id = 4821;


-- ============================================================
-- TEMPORAL FEATURES — Bi-temporal Database Design
-- ============================================================

-- Two time dimensions modeled on the `incident` table:
--   valid_from / valid_to  → VALID TIME  (when fact is true in reality)
--   recorded_at            → TRANSACTION TIME (when DB recorded it)

-- ─── T1: Temporal incident table (already defined in schema)
--     valid_from  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
--     valid_to    TIMESTAMPTZ  NOT NULL DEFAULT 'infinity'
--     recorded_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()

-- ─── T2: Update incident status — maintain valid time history
--     Instead of in-place UPDATE, close old record and insert new

CREATE OR REPLACE PROCEDURE sp_update_incident_status(
    p_incident_id   INT,
    p_new_status    incident_status,
    p_resolved_time TIMESTAMPTZ DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    -- Close the current valid record
    UPDATE incident
    SET    valid_to = NOW()
    WHERE  incident_id = p_incident_id
      AND  valid_to    = 'infinity';

    -- Insert new version with updated status
    INSERT INTO incident (
        incident_id, category, incident_time, resolved_time,
        reported_by, severity, status,
        location, road_id, zone_id, description,
        valid_from, valid_to, recorded_at
    )
    SELECT
        incident_id, category, incident_time,
        COALESCE(p_resolved_time, resolved_time),
        reported_by, severity, p_new_status,
        location, road_id, zone_id, description,
        NOW(), 'infinity', NOW()
    FROM incident
    WHERE incident_id = p_incident_id
      AND valid_to    < 'infinity'   -- the row we just closed
    ORDER BY valid_to DESC
    LIMIT 1;
END;
$$;

-- ─── T3: Query incident state at a specific past time ────────
-- "What was the status of incident 4821 at 14:25:00?"
SELECT
    incident_id, status, severity,
    valid_from, valid_to, recorded_at
FROM incident
WHERE incident_id = 4821
  AND valid_from <= '2025-04-08 14:25:00+00'
  AND valid_to   >  '2025-04-08 14:25:00+00';

-- ─── T4: Full history of an incident (all versions) ─────────
SELECT
    incident_id, status, severity,
    valid_from,
    CASE WHEN valid_to = 'infinity' THEN 'CURRENT' ELSE valid_to::TEXT END AS valid_to,
    recorded_at
FROM incident
WHERE incident_id = 4821
ORDER BY valid_from ASC;

-- ─── T5: Sensor readings — time-range query (partition pruning)
-- PostgreSQL uses partition pruning automatically on reading_time
SELECT
    sr.reading_time,
    sr.speed_kmh,
    sr.vehicle_count,
    s.sensor_type,
    r.road_name
FROM sensor_reading sr
JOIN sensor s ON s.sensor_id = sr.sensor_id
JOIN road   r ON r.road_id   = s.road_id
WHERE sr.reading_time BETWEEN '2025-04-08 14:00:00+00'
                          AND '2025-04-08 15:00:00+00'
  AND sr.sensor_id = 1042
ORDER BY sr.reading_time ASC;

-- ─── T6: Violation history — temporal range query ────────────
-- "How many violations were issued between 7am–9am today?"
SELECT
    COUNT(*)                        AS total_violations,
    AVG(recorded_speed_kmh)         AS avg_speed,
    AVG(recorded_speed_kmh - speed_limit_kmh) AS avg_excess,
    SUM(fine_amount_usd)            AS total_fines_usd
FROM violation
WHERE violation_time BETWEEN
    date_trunc('day', NOW()) + INTERVAL '7 hours'
  AND date_trunc('day', NOW()) + INTERVAL '9 hours';

-- ─── T7: Time-series aggregation — hourly traffic density ────
SELECT
    date_trunc('hour', sr.reading_time)  AS hour_bucket,
    AVG(sr.vehicle_count)                AS avg_vehicles,
    AVG(sr.occupancy_pct)                AS avg_occupancy,
    MAX(sr.speed_kmh)                    AS max_speed,
    MIN(sr.speed_kmh)                    AS min_speed
FROM sensor_reading sr
JOIN sensor s ON s.sensor_id = sr.sensor_id
JOIN road   r ON r.road_id   = s.road_id
WHERE r.road_id      = 301
  AND sr.reading_time >= NOW() - INTERVAL '24 hours'
GROUP BY hour_bucket
ORDER BY hour_bucket DESC;

-- ─── T8: TSTZRANGE — overlap query using range type ──────────
-- Find dispatches that overlapped with a given time window
ALTER TABLE dispatch ADD COLUMN IF NOT EXISTS
    active_period TSTZRANGE GENERATED ALWAYS AS (
        tstzrange(dispatch_time, COALESCE(clear_time, 'infinity'))
    ) STORED;

SELECT
    d.dispatch_id,
    d.unit_id,
    d.incident_id,
    d.dispatch_time,
    d.clear_time
FROM dispatch d
WHERE d.active_period && tstzrange(
    '2025-04-08 14:00:00+00',
    '2025-04-08 16:00:00+00'
);
