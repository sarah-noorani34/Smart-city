-- ============================================================
-- Step 5: Materialized view for query optimization demo
-- ============================================================

CREATE MATERIALIZED VIEW mv_zone_traffic_summary AS
SELECT
    z.zone_id,
    z.zone_name,
    COUNT(DISTINCT i.incident_id)                                           AS active_incidents,
    COUNT(DISTINCT CASE WHEN i.severity = 'CRITICAL' THEN i.incident_id END) AS critical_incidents,
    COALESCE(AVG(sr.vehicle_count), 0)                                      AS avg_vehicle_count,
    COALESCE(AVG(sr.occupancy_pct), 0)                                      AS avg_occupancy_pct,
    COALESCE(AVG(sr.speed_kmh), 0)                                          AS avg_speed_kmh,
    NOW()                                                                   AS last_refreshed
FROM zone z
LEFT JOIN incident i
       ON i.zone_id = z.zone_id
      AND i.status NOT IN ('RESOLVED', 'CLOSED')
      AND i.valid_to = 'infinity'
LEFT JOIN road r     ON r.zone_id   = z.zone_id
LEFT JOIN sensor s   ON s.road_id   = r.road_id
LEFT JOIN sensor_reading sr
       ON sr.sensor_id   = s.sensor_id
      AND sr.reading_time >= NOW() - INTERVAL '15 minutes'
GROUP BY z.zone_id, z.zone_name
WITH DATA;

CREATE UNIQUE INDEX ON mv_zone_traffic_summary(zone_id);

\echo '✓ Materialized view created'
\echo ''
\echo '=== Zone Traffic Summary ==='
SELECT zone_name, active_incidents, critical_incidents,
       ROUND(avg_vehicle_count::numeric,1) AS avg_vehicles,
       ROUND(avg_speed_kmh::numeric,1) AS avg_speed
FROM mv_zone_traffic_summary
ORDER BY active_incidents DESC;
