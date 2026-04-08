-- ============================================================
-- 11. SAMPLE QUERIES
--     Smart City Traffic & Emergency Management System
-- ============================================================

-- ============================================================
-- SQL QUERY 1
-- Goal: Real-time dashboard — active incidents with dispatch
--       details, unit ETA, and zone traffic pressure score.
-- ============================================================
SELECT
    i.incident_id,
    i.category,
    i.severity,
    i.status,
    i.incident_time,
    ROUND(EXTRACT(EPOCH FROM (NOW() - i.incident_time)) / 60.0, 1)   AS age_min,
    z.zone_name,
    z.zone_type,
    ST_AsText(i.location)                                              AS location_wkt,
    COUNT(DISTINCT d.dispatch_id)                                      AS units_dispatched,
    STRING_AGG(DISTINCT eu.unit_type, ', ' ORDER BY eu.unit_type)     AS unit_types,
    ROUND(AVG(
        CASE WHEN d.arrival_time IS NOT NULL
             THEN EXTRACT(EPOCH FROM (d.arrival_time - d.dispatch_time)) / 60.0
        END
    )::numeric, 1)                                                     AS avg_arrival_min,
    mv.avg_vehicle_count                                               AS zone_avg_vehicles,
    mv.avg_occupancy_pct                                               AS zone_occupancy
FROM incident i
JOIN zone z                     ON z.zone_id    = i.zone_id
LEFT JOIN dispatch d            ON d.incident_id = i.incident_id
LEFT JOIN emergency_unit eu     ON eu.unit_id    = d.unit_id
LEFT JOIN mv_zone_traffic_summary mv ON mv.zone_id = z.zone_id
WHERE i.status NOT IN ('RESOLVED', 'CLOSED')
  AND i.valid_to = 'infinity'
GROUP BY
    i.incident_id, i.category, i.severity, i.status,
    i.incident_time, i.location,
    z.zone_name, z.zone_type,
    mv.avg_vehicle_count, mv.avg_occupancy_pct
ORDER BY
    CASE i.severity
        WHEN 'CRITICAL' THEN 1
        WHEN 'HIGH'     THEN 2
        WHEN 'MEDIUM'   THEN 3
        ELSE                 4
    END,
    i.incident_time ASC;


-- ============================================================
-- SQL QUERY 2
-- Goal: Speed violation hotspot analysis — top 10 road
--       segments by violation count in last 30 days, with
--       average excess speed and total fines collected.
-- ============================================================
SELECT
    r.road_id,
    r.road_name,
    r.road_type,
    r.speed_limit_kmh,
    z.zone_name,
    COUNT(v.violation_id)                                        AS total_violations,
    COUNT(DISTINCT v.vehicle_id)                                 AS unique_vehicles,
    ROUND(AVG(v.recorded_speed_kmh - v.speed_limit_kmh)::numeric, 1) AS avg_excess_kmh,
    MAX(v.recorded_speed_kmh)                                    AS max_speed_recorded,
    SUM(v.fine_amount_usd)                                       AS total_fines_usd,
    SUM(CASE WHEN v.paid THEN v.fine_amount_usd ELSE 0 END)     AS collected_fines_usd,
    ROUND(
        100.0 * SUM(CASE WHEN v.paid THEN 1 ELSE 0 END) / COUNT(*), 1
    )                                                            AS payment_rate_pct
FROM road r
JOIN zone z     ON z.zone_id   = r.zone_id
JOIN sensor s   ON s.road_id   = r.road_id AND s.sensor_type = 'SPEED'
JOIN violation v ON v.sensor_id = s.sensor_id
WHERE v.violation_time >= NOW() - INTERVAL '30 days'
GROUP BY r.road_id, r.road_name, r.road_type, r.speed_limit_kmh, z.zone_name
HAVING COUNT(v.violation_id) >= 5
ORDER BY total_violations DESC, avg_excess_kmh DESC
LIMIT 10;


-- ============================================================
-- SQL QUERY 3
-- Goal: Emergency unit performance report — response time
--       statistics per unit over last 90 days, including
--       incidents handled, on-time arrivals (< 8 min), and
--       current availability.
-- ============================================================
WITH unit_stats AS (
    SELECT
        eu.unit_id,
        eu.unit_type,
        eu.agency_name,
        eu.availability_status,
        COUNT(d.dispatch_id)                                               AS total_dispatches,
        COUNT(CASE WHEN d.arrival_time IS NOT NULL THEN 1 END)            AS arrived_count,
        ROUND(AVG(
            CASE WHEN d.arrival_time IS NOT NULL
                 THEN EXTRACT(EPOCH FROM (d.arrival_time - d.dispatch_time)) / 60.0
            END
        )::numeric, 2)                                                     AS avg_response_min,
        MIN(
            CASE WHEN d.arrival_time IS NOT NULL
                 THEN EXTRACT(EPOCH FROM (d.arrival_time - d.dispatch_time)) / 60.0
            END
        )::numeric                                                         AS best_response_min,
        COUNT(
            CASE WHEN d.arrival_time IS NOT NULL
                  AND EXTRACT(EPOCH FROM (d.arrival_time - d.dispatch_time)) / 60.0 <= 8
                 THEN 1
            END
        )                                                                  AS on_time_arrivals
    FROM emergency_unit eu
    LEFT JOIN dispatch d
           ON d.unit_id      = eu.unit_id
          AND d.dispatch_time >= NOW() - INTERVAL '90 days'
    GROUP BY eu.unit_id, eu.unit_type, eu.agency_name, eu.availability_status
)
SELECT
    unit_id,
    unit_type,
    agency_name,
    availability_status,
    total_dispatches,
    arrived_count,
    avg_response_min,
    best_response_min,
    on_time_arrivals,
    CASE WHEN arrived_count > 0
         THEN ROUND(100.0 * on_time_arrivals / arrived_count, 1)
         ELSE NULL
    END                                                                    AS on_time_pct,
    RANK() OVER (
        PARTITION BY unit_type
        ORDER BY avg_response_min ASC NULLS LAST
    )                                                                      AS rank_in_type
FROM unit_stats
WHERE total_dispatches > 0
ORDER BY unit_type, avg_response_min ASC NULLS LAST;


-- ============================================================
-- MONGODB QUERY 1
-- Goal: Count incidents per zone for the last 24 hours,
--       grouped by severity.  Returns zone, severity, count,
--       and the most recent incident timestamp.
-- ============================================================
/*
db.incident_events.aggregate([
  // Stage 1: Filter recent events that represent new incident reports
  {
    $match: {
      event_type: "STATUS_CHANGED",
      previous_state: { $exists: false },          // initial insert events
      timestamp: { $gte: new Date(Date.now() - 86400000) }
    }
  },

  // Stage 2: Group by zone + severity
  {
    $group: {
      _id: {
        zone:     "$zone",
        severity: "$severity"
      },
      incident_count:  { $sum: 1 },
      latest_incident: { $max: "$timestamp" },
      incident_ids:    { $addToSet: "$incident_id" }
    }
  },

  // Stage 3: Project clean output
  {
    $project: {
      _id:             0,
      zone:            "$_id.zone",
      severity:        "$_id.severity",
      incident_count:  1,
      latest_incident: 1,
      unique_incidents: { $size: "$incident_ids" }
    }
  },

  // Stage 4: Sort by count descending
  { $sort: { incident_count: -1, severity: 1 } },

  // Stage 5: Group again to pivot severity into columns per zone
  {
    $group: {
      _id: "$zone",
      total: { $sum: "$incident_count" },
      breakdown: {
        $push: {
          severity: "$severity",
          count:    "$incident_count"
        }
      },
      last_event: { $max: "$latest_incident" }
    }
  },

  { $sort: { total: -1 } },
  { $limit: 20 }
])
*/


-- ============================================================
-- MONGODB QUERY 2
-- Goal: Geospatial query — find all sensor logs within 1.5 km
--       of a given incident location where speed > 100 km/h,
--       from the last 2 hours.  Returns sensor ID, speed,
--       distance, and timestamp.
-- ============================================================
/*
db.sensor_logs.aggregate([
  // Stage 1: Geo filter — near incident location
  {
    $geoNear: {
      near: {
        type:        "Point",
        coordinates: [67.0512, 24.8732]     // incident location
      },
      distanceField:   "dist_meters",
      maxDistance:     1500,                 // 1.5 km
      spherical:       true,
      query: {
        timestamp:              { $gte: new Date(Date.now() - 7200000) },
        speed_kmh:              { $gt: 100 },
        "sensor_meta.sensor_type": "SPEED"
      }
    }
  },

  // Stage 2: Project relevant fields
  {
    $project: {
      _id:         0,
      sensor_id:   "$sensor_meta.sensor_id",
      road_id:     "$sensor_meta.road_id",
      zone:        "$sensor_meta.zone",
      speed_kmh:   1,
      timestamp:   1,
      dist_meters: { $round: ["$dist_meters", 1] }
    }
  },

  // Stage 3: Sort by speed descending
  { $sort: { speed_kmh: -1 } },

  { $limit: 50 }
])
*/
