-- ============================================================
-- Step 3: Load PL/pgSQL procedures and triggers
-- Source: 07_plsql_code.sql
-- ============================================================

-- ── PROCEDURE 1: sp_dispatch_nearest_unit ───────────────────
CREATE OR REPLACE PROCEDURE sp_dispatch_nearest_unit(
    p_incident_id   INT,
    p_unit_type     VARCHAR(30),
    OUT p_dispatch_id   INT,
    OUT p_unit_id       INT,
    OUT p_message       TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    cur_units CURSOR FOR
        SELECT
            eu.unit_id,
            eu.agency_name,
            eu.current_location,
            ST_Distance(
                eu.current_location::geography,
                i.location::geography
            ) AS dist_meters
        FROM emergency_unit eu
        CROSS JOIN incident i
        WHERE i.incident_id   = p_incident_id
          AND eu.unit_type    = p_unit_type
          AND eu.availability_status = 'AVAILABLE'
          AND eu.current_location IS NOT NULL
        ORDER BY dist_meters ASC;

    rec_unit        RECORD;
    v_incident_loc  GEOMETRY(POINT, 4326);
    v_incident_zone INT;
    v_incident_sev  severity_level;
    v_found         BOOLEAN := FALSE;
BEGIN
    SELECT location, zone_id, severity
    INTO   v_incident_loc, v_incident_zone, v_incident_sev
    FROM   incident
    WHERE  incident_id = p_incident_id
      AND  status IN ('REPORTED', 'IN_PROGRESS')
      AND  valid_to = 'infinity';

    IF NOT FOUND THEN
        p_message := 'ERROR: Incident ' || p_incident_id || ' not found or not in a dispatchable state.';
        p_dispatch_id := NULL;
        p_unit_id     := NULL;
        RETURN;
    END IF;

    OPEN cur_units;
    FETCH cur_units INTO rec_unit;

    IF FOUND THEN
        p_unit_id := rec_unit.unit_id;

        INSERT INTO dispatch (unit_id, incident_id, dispatch_time)
        VALUES (rec_unit.unit_id, p_incident_id, NOW())
        RETURNING dispatch_id INTO p_dispatch_id;

        UPDATE emergency_unit
        SET    availability_status = 'DISPATCHED',
               last_status_update  = NOW()
        WHERE  unit_id = rec_unit.unit_id;

        UPDATE incident
        SET    status     = 'DISPATCHED',
               valid_from = NOW()
        WHERE  incident_id = p_incident_id
          AND  valid_to    = 'infinity';

        INSERT INTO audit_log (table_name, operation, record_id, new_values)
        VALUES (
            'dispatch', 'INSERT', p_dispatch_id,
            jsonb_build_object(
                'unit_id',     rec_unit.unit_id,
                'incident_id', p_incident_id,
                'dist_m',      ROUND(rec_unit.dist_meters::numeric, 1),
                'agency',      rec_unit.agency_name
            )
        );

        p_message := 'SUCCESS: Unit ' || rec_unit.unit_id ||
                     ' (' || rec_unit.agency_name || ') dispatched. ' ||
                     'Distance: ' || ROUND(rec_unit.dist_meters::numeric, 0) || ' m.';
    ELSE
        p_message := 'WARNING: No available ' || p_unit_type ||
                     ' unit found for incident ' || p_incident_id || '.';
        p_dispatch_id := NULL;
        p_unit_id     := NULL;
    END IF;

    CLOSE cur_units;

EXCEPTION
    WHEN OTHERS THEN
        IF cur_units%ISOPEN THEN CLOSE cur_units; END IF;
        p_message := 'EXCEPTION: ' || SQLERRM;
        p_dispatch_id := NULL;
        p_unit_id     := NULL;
        RAISE NOTICE 'sp_dispatch_nearest_unit failed: %', SQLERRM;
END;
$$;

-- ── PROCEDURE 2: sp_optimize_signal_timing ──────────────────
CREATE OR REPLACE PROCEDURE sp_optimize_signal_timing(
    p_intersection_id   INT,
    OUT p_adjusted       BOOLEAN,
    OUT p_message        TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    cur_road_load CURSOR FOR
        SELECT
            r.road_id,
            r.road_name,
            r.lanes,
            COALESCE(AVG(sr.vehicle_count), 0)   AS avg_vehicles,
            COALESCE(AVG(sr.occupancy_pct), 0)   AS avg_occupancy,
            COALESCE(AVG(sr.speed_kmh), 30)       AS avg_speed
        FROM (
            SELECT road_id_1 AS road_id FROM intersection WHERE intersection_id = p_intersection_id
            UNION
            SELECT road_id_2 AS road_id FROM intersection WHERE intersection_id = p_intersection_id
        ) ri
        JOIN road r ON r.road_id = ri.road_id
        LEFT JOIN sensor s ON s.road_id = r.road_id AND s.sensor_type = 'INDUCTIVE_LOOP'
        LEFT JOIN sensor_reading sr
               ON sr.sensor_id  = s.sensor_id
              AND sr.reading_time >= NOW() - INTERVAL '15 minutes'
        GROUP BY r.road_id, r.road_name, r.lanes;

    rec             RECORD;
    v_signal_id     INT;
    v_is_adaptive   BOOLEAN;
    v_total_load    NUMERIC := 0;
    v_road1_load    NUMERIC := 0;
    v_road2_load    NUMERIC := 0;
    v_road1_id      INT;
    v_road2_id      INT;
    v_new_green_r1  SMALLINT;
    v_new_green_r2  SMALLINT;
    v_cycle_total   SMALLINT := 90;
    v_min_green     SMALLINT := 15;
    v_max_green     SMALLINT := 60;
    v_row_count     INT := 0;
BEGIN
    SELECT signal_id, is_adaptive
    INTO   v_signal_id, v_is_adaptive
    FROM   traffic_signal
    WHERE  intersection_id = p_intersection_id;

    IF NOT FOUND THEN
        p_adjusted := FALSE;
        p_message  := 'ERROR: No signal found for intersection ' || p_intersection_id;
        RETURN;
    END IF;

    IF NOT v_is_adaptive THEN
        p_adjusted := FALSE;
        p_message  := 'SKIP: Signal ' || v_signal_id || ' is not adaptive.';
        RETURN;
    END IF;

    OPEN cur_road_load;
    LOOP
        FETCH cur_road_load INTO rec;
        EXIT WHEN NOT FOUND;
        v_row_count := v_row_count + 1;

        DECLARE road_load NUMERIC;
        BEGIN
            road_load := (rec.avg_vehicles * (1 + rec.avg_occupancy / 100.0)) / GREATEST(rec.lanes, 1);
            v_total_load := v_total_load + road_load;
            IF v_row_count = 1 THEN
                v_road1_id   := rec.road_id;
                v_road1_load := road_load;
            ELSE
                v_road2_id   := rec.road_id;
                v_road2_load := road_load;
            END IF;
        END;
    END LOOP;
    CLOSE cur_road_load;

    IF v_row_count < 2 OR v_total_load = 0 THEN
        p_adjusted := FALSE;
        p_message  := 'INFO: Insufficient sensor data for intersection ' || p_intersection_id;
        RETURN;
    END IF;

    v_new_green_r1 := GREATEST(v_min_green,
                          LEAST(v_max_green,
                              ROUND((v_road1_load / v_total_load) * (v_cycle_total - 10))::SMALLINT));
    v_new_green_r2 := GREATEST(v_min_green,
                          LEAST(v_max_green,
                              v_cycle_total - 10 - v_new_green_r1));

    UPDATE traffic_signal
    SET    green_duration_sec  = v_new_green_r1,
           red_duration_sec    = v_new_green_r2 + 5,
           last_updated        = NOW()
    WHERE  signal_id = v_signal_id;

    INSERT INTO audit_log (table_name, operation, record_id, new_values)
    VALUES (
        'traffic_signal', 'UPDATE', v_signal_id,
        jsonb_build_object(
            'intersection_id', p_intersection_id,
            'road1_id', v_road1_id, 'road1_load', ROUND(v_road1_load::numeric, 2),
            'road2_id', v_road2_id, 'road2_load', ROUND(v_road2_load::numeric, 2),
            'new_green_r1', v_new_green_r1, 'new_green_r2', v_new_green_r2
        )
    );

    p_adjusted := TRUE;
    p_message  := 'SUCCESS: Signal ' || v_signal_id ||
                  ' updated. Road-1 green=' || v_new_green_r1 ||
                  's, Road-2 green=' || v_new_green_r2 || 's.';

EXCEPTION
    WHEN OTHERS THEN
        IF cur_road_load%ISOPEN THEN CLOSE cur_road_load; END IF;
        p_adjusted := FALSE;
        p_message  := 'EXCEPTION: ' || SQLERRM;
END;
$$;

-- ── TRIGGER 1: trg_incident_alert ───────────────────────────
CREATE OR REPLACE FUNCTION fn_incident_alert()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_sig           RECORD;
    v_dispatch_id   INT;
    v_unit_id       INT;
    v_msg           TEXT;
    v_unit_type     VARCHAR(30);
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, new_values)
    VALUES (
        'incident', 'INSERT', NEW.incident_id,
        jsonb_build_object(
            'category', NEW.category, 'severity', NEW.severity,
            'status',   NEW.status,   'zone_id',  NEW.zone_id,
            'incident_time', NEW.incident_time
        )
    );

    IF NEW.severity IN ('HIGH', 'CRITICAL') THEN
        FOR v_sig IN
            SELECT ts.signal_id
            FROM   traffic_signal ts
            JOIN   intersection inx ON inx.intersection_id = ts.intersection_id
            WHERE  ST_DWithin(inx.location::geography, NEW.location::geography, 1000)
        LOOP
            UPDATE traffic_signal
            SET    current_phase = 'RED', last_updated = NOW()
            WHERE  signal_id = v_sig.signal_id;
        END LOOP;
    END IF;

    IF NEW.severity = 'CRITICAL' THEN
        CASE NEW.category
            WHEN 'ACCIDENT'        THEN v_unit_type := 'AMBULANCE';
            WHEN 'EMERGENCY_EVENT' THEN v_unit_type := 'FIRE_TRUCK';
            ELSE                        v_unit_type := 'POLICE';
        END CASE;

        CALL sp_dispatch_nearest_unit(NEW.incident_id, v_unit_type, v_dispatch_id, v_unit_id, v_msg);
        RAISE NOTICE '[CRITICAL INCIDENT %] Auto-dispatch: %', NEW.incident_id, v_msg;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_incident_alert
AFTER INSERT ON incident
FOR EACH ROW
EXECUTE FUNCTION fn_incident_alert();

-- ── TRIGGER 2: trg_speed_violation_check ────────────────────
CREATE OR REPLACE FUNCTION fn_speed_violation_check()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    v_speed_limit   SMALLINT;
    v_road_id       INT;
    v_vehicle       RECORD;
    v_fine_amount   NUMERIC(8,2);
    v_excess_kmh    NUMERIC(5,2);
    v_demerit       SMALLINT := 0;
    v_sensor_type   sensor_type_enum;
BEGIN
    SELECT sensor_type INTO v_sensor_type FROM sensor WHERE sensor_id = NEW.sensor_id;
    IF v_sensor_type <> 'SPEED' THEN RETURN NEW; END IF;
    IF NEW.speed_kmh IS NULL OR NEW.speed_kmh <= 0 THEN RETURN NEW; END IF;

    SELECT r.road_id, r.speed_limit_kmh
    INTO   v_road_id, v_speed_limit
    FROM   sensor s JOIN road r ON r.road_id = s.road_id
    WHERE  s.sensor_id = NEW.sensor_id;

    IF NOT FOUND THEN RETURN NEW; END IF;

    v_excess_kmh := NEW.speed_kmh - v_speed_limit;
    IF v_excess_kmh <= 0 THEN RETURN NEW; END IF;

    v_fine_amount := CASE
        WHEN v_excess_kmh <=  10 THEN  50.00
        WHEN v_excess_kmh <=  20 THEN 150.00
        WHEN v_excess_kmh <=  40 THEN 350.00
        ELSE                          700.00
    END;

    v_demerit := CASE
        WHEN v_excess_kmh <=  10 THEN 1
        WHEN v_excess_kmh <=  20 THEN 2
        WHEN v_excess_kmh <=  40 THEN 3
        ELSE                          4
    END;

    INSERT INTO violation (vehicle_id, sensor_id, violation_time, recorded_speed_kmh, speed_limit_kmh, fine_amount_usd)
    VALUES (NULL, NEW.sensor_id, NEW.reading_time, NEW.speed_kmh, v_speed_limit, v_fine_amount);

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_speed_violation_check
AFTER INSERT ON sensor_reading
FOR EACH ROW
EXECUTE FUNCTION fn_speed_violation_check();

-- ── PROCEDURE 3: sp_zone_congestion_report ──────────────────
CREATE OR REPLACE PROCEDURE sp_zone_congestion_report(p_zone_id INT DEFAULT NULL)
LANGUAGE plpgsql AS $$
DECLARE
    cur_zones CURSOR FOR
        SELECT
            z.zone_id, z.zone_name,
            COUNT(i.incident_id)                                    AS open_incidents,
            COUNT(CASE WHEN i.severity='CRITICAL' THEN 1 END)      AS critical_count,
            COALESCE(AVG(c.avg_speed_kmh), 0)                      AS avg_speed,
            COALESCE(SUM(c.affected_length_km), 0)                 AS total_congestion_km
        FROM zone z
        LEFT JOIN incident  i ON i.zone_id = z.zone_id AND i.status NOT IN ('RESOLVED','CLOSED') AND i.valid_to = 'infinity'
        LEFT JOIN congestion c ON c.incident_id = i.incident_id
        WHERE (p_zone_id IS NULL OR z.zone_id = p_zone_id)
        GROUP BY z.zone_id, z.zone_name
        ORDER BY open_incidents DESC;
    rec RECORD;
BEGIN
    RAISE NOTICE '%-5s %-25s %10s %10s %12s %18s', 'ZID','ZONE','INCIDENTS','CRITICAL','AVG SPD','CONGESTION(km)';
    OPEN cur_zones;
    LOOP
        FETCH cur_zones INTO rec;
        EXIT WHEN NOT FOUND;
        RAISE NOTICE '%-5s %-25s %10s %10s %12s %18s',
            rec.zone_id, rec.zone_name, rec.open_incidents, rec.critical_count,
            ROUND(rec.avg_speed::numeric,1), ROUND(rec.total_congestion_km::numeric,2);
    END LOOP;
    CLOSE cur_zones;
END;
$$;

-- ── Temporal: sp_update_incident_status ─────────────────────
CREATE OR REPLACE PROCEDURE sp_update_incident_status(
    p_incident_id   INT,
    p_new_status    incident_status,
    p_resolved_time TIMESTAMPTZ DEFAULT NULL
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE incident SET valid_to = NOW()
    WHERE  incident_id = p_incident_id AND valid_to = 'infinity';

    INSERT INTO incident (
        incident_id, category, incident_time, resolved_time,
        reported_by, severity, status, location, road_id, zone_id, description,
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
    ORDER BY valid_to DESC LIMIT 1;
END;
$$;

\echo '✓ Procedures and triggers loaded successfully'
