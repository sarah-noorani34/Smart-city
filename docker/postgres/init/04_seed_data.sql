-- ============================================================
-- Step 4: Seed data — realistic test data for demos
-- ============================================================

-- Zones
INSERT INTO zone (zone_name, zone_type, city_region, boundary) VALUES
('CENTRAL_HIGHWAY',  'HIGHWAY',     'CENTRAL', ST_GeomFromText('POLYGON((67.04 24.86, 67.07 24.86, 67.07 24.89, 67.04 24.89, 67.04 24.86))', 4326)),
('NORTH_RESIDENTIAL','RESIDENTIAL', 'NORTH',   ST_GeomFromText('POLYGON((67.05 24.90, 67.08 24.90, 67.08 24.93, 67.05 24.93, 67.05 24.90))', 4326)),
('EAST_COMMERCIAL',  'COMMERCIAL',  'EAST',    ST_GeomFromText('POLYGON((67.08 24.86, 67.11 24.86, 67.11 24.89, 67.08 24.89, 67.08 24.86))', 4326)),
('WEST_INDUSTRIAL',  'INDUSTRIAL',  'WEST',    ST_GeomFromText('POLYGON((67.01 24.86, 67.04 24.86, 67.04 24.89, 67.01 24.89, 67.01 24.86))', 4326)),
('SOUTH_HOSPITAL',   'HOSPITAL_ZONE','SOUTH',  ST_GeomFromText('POLYGON((67.04 24.83, 67.07 24.83, 67.07 24.86, 67.04 24.86, 67.04 24.83))', 4326));

-- People
INSERT INTO person (full_name, date_of_birth, contact_number, email, address) VALUES
('Amir Raza',       '1990-05-15', '+92-300-1234567', 'amir.raza@email.com',    '12 Garden Road, Karachi'),
('Sara Malik',      '1985-09-22', '+92-321-2345678', 'sara.malik@email.com',   '45 Clifton Block 5, Karachi'),
('Dr. Sana Mirza',  '1988-03-10', '+92-333-3456789', 'sana.mirza@email.com',   'Edhi Centre, Karachi'),
('Inspector Fahad', '1982-07-18', '+92-301-4567890', 'fahad.khan@ktp.gov.pk',  'Police HQ, Karachi'),
('Bilal Yusuf',     '1995-11-30', '+92-315-5678901', 'bilal.yusuf@email.com',  '88 North Nazimabad, Karachi'),
('Raheem Khan',     '1987-04-25', '+92-322-6789012', 'raheem.khan@email.com',  '33 Gulshan Block 7, Karachi');

-- Drivers (subclass of person)
INSERT INTO driver (person_id, license_number, license_expiry, demerit_points) VALUES
(1, 'KHI-DL-2019-00421', '2026-05-14', 2),
(2, 'KHI-DL-2017-00889', '2025-09-21', 0),
(5, 'KHI-DL-2020-01122', '2027-11-29', 5);

-- Emergency responder
INSERT INTO emergency_responder (person_id, badge_number, specialization, agency_name, shift_start, shift_end) VALUES
(3, 'ER-4422', 'Trauma & Emergency Care', 'Edhi Foundation', '08:00', '20:00');

-- Traffic officer
INSERT INTO traffic_officer (person_id, badge_number, jurisdiction, rank) VALUES
(4, 'KTP-0177', 'Central Zone', 'Inspector');

-- Vehicles
INSERT INTO vehicle (license_plate, make, model, year, color, category, owner_id) VALUES
('KHI-1234',    'Toyota',   'Corolla',  2020, 'White',  'PRIVATE',   1),
('KHI-5678',    'Honda',    'Civic',    2022, 'Silver', 'PRIVATE',   2),
('KHI-BUS-09',  'Hino',     'Rainbow',  2019, 'Yellow', 'PUBLIC',    6),
('KHI-AMB-021', 'Toyota',   'HiAce',   2023, 'White',  'EMERGENCY', 3),
('KHI-AMB-034', 'Mercedes', 'Sprinter', 2022, 'White',  'EMERGENCY', 3),
('KHI-POL-117', 'Toyota',   'Hilux',   2021, 'Black',  'EMERGENCY', 4);

-- Private vehicles
INSERT INTO private_vehicle (vehicle_id, registration_expiry, insurance_policy_no, insurance_expiry) VALUES
(1, '2025-12-31', 'EFU-2023-441221', '2025-12-31'),
(2, '2026-06-30', 'AIC-2022-882110', '2026-06-30');

-- Public vehicle
INSERT INTO public_vehicle (vehicle_id, route_number, operator_id, seating_capacity) VALUES
(3, 'BUS-22A', 6, 40);

-- Emergency vehicles
INSERT INTO emergency_vehicle (vehicle_id, unit_code, agency_name, equipment_list) VALUES
(4, 'AMB-021', 'Edhi Foundation',  ARRAY['defibrillator','oxygen_tank','stretcher','IV_kit']),
(5, 'AMB-034', 'Aman Foundation',  ARRAY['defibrillator','oxygen_tank','stretcher','trauma_bag']),
(6, 'POL-117', 'Karachi Traffic Police', ARRAY['radio','first_aid','speed_gun','bodycam']);

-- Roads
INSERT INTO road (road_name, road_type, speed_limit_kmh, lanes, zone_id, road_geom, length_km, is_one_way) VALUES
('Main Sharea Faisal',  'ARTERIAL',   80, 6, 1, ST_GeomFromText('LINESTRING(67.040 24.860, 67.051 24.873, 67.062 24.880)', 4326), 3.2, FALSE),
('Korangi Road',        'ARTERIAL',   70, 4, 3, ST_GeomFromText('LINESTRING(67.080 24.860, 67.068 24.870, 67.055 24.875)', 4326), 4.1, FALSE),
('North Nazimabad Blvd','LOCAL',      60, 2, 2, ST_GeomFromText('LINESTRING(67.050 24.900, 67.060 24.910, 67.070 24.920)', 4326), 2.5, FALSE),
('Hospital Access Road','LOCAL',      40, 2, 5, ST_GeomFromText('LINESTRING(67.045 24.840, 67.050 24.850, 67.055 24.855)', 4326), 1.8, FALSE),
('Drigh Road',          'HIGHWAY',    100,6, 1, ST_GeomFromText('LINESTRING(67.020 24.865, 67.035 24.867, 67.050 24.870)', 4326), 5.6, FALSE);

-- Intersections
INSERT INTO intersection (location, road_id_1, road_id_2, intersection_name) VALUES
(ST_GeomFromText('POINT(67.051 24.873)', 4326), 1, 5, 'Sharea Faisal × Drigh Road'),
(ST_GeomFromText('POINT(67.055 24.875)', 4326), 1, 2, 'Sharea Faisal × Korangi Road'),
(ST_GeomFromText('POINT(67.050 24.855)', 4326), 4, 1, 'Hospital Rd × Sharea Faisal');

-- Traffic Signals
INSERT INTO traffic_signal (intersection_id, current_phase, green_duration_sec, yellow_duration_sec, red_duration_sec, is_adaptive) VALUES
(1, 'GREEN', 45, 5, 40, TRUE),
(2, 'RED',   30, 5, 30, TRUE),
(3, 'GREEN', 25, 5, 50, FALSE);

-- Sensors
INSERT INTO sensor (sensor_type, road_id, location, install_date, status, model_no) VALUES
('SPEED',          1, ST_GeomFromText('POINT(67.048 24.868)', 4326), '2023-03-15', 'ACTIVE', 'SPD-3000'),
('INDUCTIVE_LOOP', 1, ST_GeomFromText('POINT(67.050 24.870)', 4326), '2023-03-15', 'ACTIVE', 'ILD-500'),
('SPEED',          2, ST_GeomFromText('POINT(67.060 24.865)', 4326), '2023-06-01', 'ACTIVE', 'SPD-3000'),
('CAMERA',         1, ST_GeomFromText('POINT(67.051 24.873)', 4326), '2023-01-10', 'ACTIVE', 'CAM-HD4K'),
('INDUCTIVE_LOOP', 5, ST_GeomFromText('POINT(67.040 24.866)', 4326), '2022-11-20', 'ACTIVE', 'ILD-500');

-- Emergency Units
INSERT INTO emergency_unit (unit_type, agency_name, vehicle_id, current_location, availability_status, home_zone_id) VALUES
('AMBULANCE', 'Edhi Foundation',       4, ST_GeomFromText('POINT(67.046 24.865)', 4326), 'AVAILABLE', 1),
('AMBULANCE', 'Aman Foundation',       5, ST_GeomFromText('POINT(67.062 24.880)', 4326), 'AVAILABLE', 1),
('POLICE',    'Karachi Traffic Police',6, ST_GeomFromText('POINT(67.044 24.864)', 4326), 'AVAILABLE', 1);

-- Emergency Station (object-relational composite types)
INSERT INTO emergency_station (station_name, station_type, address, contact, location, zone_id, capacity) VALUES
(
    'Central Emergency Hub', 'UNIFIED',
    ROW('Plot 5, Civic Centre Road', 'Karachi', 'Sindh', '75500', 'Pakistan')::address_type,
    ROW('+92-21-99203000', 'central.hub@smartcity.gov.pk', '+92-21-99203001')::contact_info_type,
    ST_GeomFromText('POINT(67.050 24.875)', 4326),
    1, 20
);

-- Sensor Readings (recent data)
INSERT INTO sensor_reading (sensor_id, reading_time, speed_kmh, vehicle_count, occupancy_pct) VALUES
(1, NOW() - INTERVAL '10 minutes', 72.5, 18, 55.0),
(1, NOW() - INTERVAL '8 minutes',  76.3, 21, 62.0),
(1, NOW() - INTERVAL '6 minutes',  68.1, 24, 71.5),
(1, NOW() - INTERVAL '4 minutes',  81.9, 19, 58.0),
(1, NOW() - INTERVAL '2 minutes',  65.4, 22, 65.0),
(2, NOW() - INTERVAL '10 minutes', 45.0, 30, 80.0),
(2, NOW() - INTERVAL '5 minutes',  42.3, 34, 85.0),
(3, NOW() - INTERVAL '10 minutes', 88.0, 12, 40.0),
(3, NOW() - INTERVAL '5 minutes',  92.1, 10, 35.0),
(5, NOW() - INTERVAL '10 minutes', 95.0, 28, 75.0),
(5, NOW() - INTERVAL '5 minutes',  98.5, 30, 78.0);

-- ── DEMO INCIDENT: triggers will fire automatically ──────────
-- This INSERT will:
--   (a) Log to audit_log
--   (b) Turn all nearby signals to RED (HIGH severity)
--   (c) Auto-dispatch nearest AMBULANCE (CRITICAL severity)
INSERT INTO incident (category, severity, status, location, zone_id, road_id, reported_by, description)
VALUES (
    'ACCIDENT', 'CRITICAL', 'REPORTED',
    ST_GeomFromText('POINT(67.051 24.873)', 4326),
    1, 1, 1,
    'Multi-vehicle collision — 3 cars involved, 1 overturned. 2 casualties reported.'
);

-- Accident subclass record
INSERT INTO accident (incident_id, casualties, property_damage_usd, fault_vehicle_id)
VALUES (1, 2, 18500.00, 1);

-- A congestion incident
INSERT INTO incident (category, severity, status, location, zone_id, road_id, reported_by, description)
VALUES (
    'CONGESTION', 'HIGH', 'REPORTED',
    ST_GeomFromText('POINT(67.040 24.866)', 4326),
    1, 5, 2,
    'Heavy congestion on Drigh Road due to accident spillover.'
);

INSERT INTO congestion (incident_id, affected_length_km, avg_speed_kmh, cause_type)
VALUES (2, 2.3, 12.5, 'ACCIDENT_SPILLOVER');

-- A speed violation (trigger fires from sensor reading above speed limit)
INSERT INTO sensor_reading (sensor_id, reading_time, speed_kmh, vehicle_count, occupancy_pct)
VALUES (1, NOW(), 127.5, 1, 5.0);  -- 127.5 on 80 km/h road → violation auto-created

\echo '✓ Seed data loaded successfully'
\echo ''
\echo '=== QUICK CHECK ==='
SELECT 'Zones'        AS entity, COUNT(*) AS count FROM zone
UNION ALL SELECT 'Roads',    COUNT(*) FROM road
UNION ALL SELECT 'Sensors',  COUNT(*) FROM sensor
UNION ALL SELECT 'Incidents',COUNT(*) FROM incident
UNION ALL SELECT 'Dispatch', COUNT(*) FROM dispatch
UNION ALL SELECT 'Violations',COUNT(*) FROM violation
UNION ALL SELECT 'Audit Logs',COUNT(*) FROM audit_log;
