-- ============================================================
-- 4. RELATIONAL SCHEMA — PostgreSQL + PostGIS
--    Smart City Traffic & Emergency Management System
-- ============================================================

-- Enable spatial extension
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ============================================================
-- ENUMERATIONS
-- ============================================================
CREATE TYPE vehicle_category    AS ENUM ('PRIVATE', 'PUBLIC', 'EMERGENCY');
CREATE TYPE incident_category   AS ENUM ('ACCIDENT', 'CONGESTION', 'EMERGENCY_EVENT');
CREATE TYPE incident_status     AS ENUM ('REPORTED', 'DISPATCHED', 'IN_PROGRESS', 'RESOLVED', 'CLOSED');
CREATE TYPE severity_level      AS ENUM ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL');
CREATE TYPE unit_status         AS ENUM ('AVAILABLE', 'DISPATCHED', 'ON_SCENE', 'RETURNING', 'OFFLINE');
CREATE TYPE signal_phase        AS ENUM ('GREEN', 'YELLOW', 'RED', 'FLASHING');
CREATE TYPE zone_type           AS ENUM ('RESIDENTIAL', 'COMMERCIAL', 'INDUSTRIAL', 'HIGHWAY', 'HOSPITAL_ZONE');
CREATE TYPE sensor_type_enum    AS ENUM ('SPEED', 'INDUCTIVE_LOOP', 'CAMERA', 'WEATHER', 'AIR_QUALITY');

-- ============================================================
-- ZONE
-- ============================================================
CREATE TABLE zone (
    zone_id         SERIAL          PRIMARY KEY,
    zone_name       VARCHAR(100)    NOT NULL UNIQUE,
    zone_type       zone_type       NOT NULL,
    city_region     VARCHAR(50)     NOT NULL,
    boundary        GEOMETRY(POLYGON, 4326),          -- PostGIS spatial
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ============================================================
-- PERSON (Superclass)
-- ============================================================
CREATE TABLE person (
    person_id       SERIAL          PRIMARY KEY,
    full_name       VARCHAR(150)    NOT NULL,
    date_of_birth   DATE            NOT NULL,
    contact_number  VARCHAR(20)     NOT NULL UNIQUE,
    email           VARCHAR(200)    UNIQUE,
    address         TEXT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Subclass: DRIVER
CREATE TABLE driver (
    person_id           INT             PRIMARY KEY REFERENCES person(person_id) ON DELETE CASCADE,
    license_number      VARCHAR(30)     NOT NULL UNIQUE,
    license_expiry      DATE            NOT NULL,
    demerit_points      SMALLINT        NOT NULL DEFAULT 0 CHECK (demerit_points >= 0),
    license_class       VARCHAR(10)     NOT NULL DEFAULT 'B'
);

-- Subclass: EMERGENCY_RESPONDER
CREATE TABLE emergency_responder (
    person_id       INT             PRIMARY KEY REFERENCES person(person_id) ON DELETE CASCADE,
    badge_number    VARCHAR(20)     NOT NULL UNIQUE,
    specialization  VARCHAR(80)     NOT NULL,
    agency_name     VARCHAR(100)    NOT NULL,
    shift_start     TIME,
    shift_end       TIME
);

-- Subclass: TRAFFIC_OFFICER
CREATE TABLE traffic_officer (
    person_id       INT             PRIMARY KEY REFERENCES person(person_id) ON DELETE CASCADE,
    badge_number    VARCHAR(20)     NOT NULL UNIQUE,
    station_id      INT,
    jurisdiction    VARCHAR(100),
    rank            VARCHAR(50)     NOT NULL DEFAULT 'OFFICER'
);

-- ============================================================
-- VEHICLE (Superclass)
-- ============================================================
CREATE TABLE vehicle (
    vehicle_id      SERIAL          PRIMARY KEY,
    license_plate   VARCHAR(20)     NOT NULL UNIQUE,
    make            VARCHAR(50)     NOT NULL,
    model           VARCHAR(50)     NOT NULL,
    year            SMALLINT        NOT NULL CHECK (year BETWEEN 1990 AND 2030),
    color           VARCHAR(30),
    category        vehicle_category NOT NULL,
    owner_id        INT             NOT NULL REFERENCES person(person_id),
    registered_at   TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Subclass: PRIVATE_VEHICLE
CREATE TABLE private_vehicle (
    vehicle_id              INT         PRIMARY KEY REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
    registration_expiry     DATE        NOT NULL,
    insurance_policy_no     VARCHAR(50) NOT NULL,
    insurance_expiry        DATE        NOT NULL
);

-- Subclass: PUBLIC_VEHICLE
CREATE TABLE public_vehicle (
    vehicle_id      INT         PRIMARY KEY REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
    route_number    VARCHAR(20) NOT NULL,
    operator_id     INT         REFERENCES person(person_id),
    seating_capacity SMALLINT   NOT NULL CHECK (seating_capacity > 0)
);

-- Subclass: EMERGENCY_VEHICLE
CREATE TABLE emergency_vehicle (
    vehicle_id      INT         PRIMARY KEY REFERENCES vehicle(vehicle_id) ON DELETE CASCADE,
    unit_code       VARCHAR(20) NOT NULL UNIQUE,
    agency_name     VARCHAR(100) NOT NULL,
    equipment_list  TEXT[]
);

-- ============================================================
-- ROAD
-- ============================================================
CREATE TABLE road (
    road_id         SERIAL          PRIMARY KEY,
    road_name       VARCHAR(150)    NOT NULL,
    road_type       VARCHAR(30)     NOT NULL,   -- 'ARTERIAL','HIGHWAY','LOCAL','EXPRESSWAY'
    speed_limit_kmh SMALLINT        NOT NULL CHECK (speed_limit_kmh > 0),
    lanes           SMALLINT        NOT NULL CHECK (lanes > 0),
    zone_id         INT             NOT NULL REFERENCES zone(zone_id),
    road_geom       GEOMETRY(LINESTRING, 4326),  -- PostGIS geometry
    length_km       NUMERIC(8,3),
    is_one_way      BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ============================================================
-- INTERSECTION
-- ============================================================
CREATE TABLE intersection (
    intersection_id SERIAL          PRIMARY KEY,
    location        GEOMETRY(POINT, 4326) NOT NULL,
    road_id_1       INT             NOT NULL REFERENCES road(road_id),
    road_id_2       INT             NOT NULL REFERENCES road(road_id),
    intersection_name VARCHAR(100),
    CONSTRAINT chk_diff_roads CHECK (road_id_1 <> road_id_2)
);

-- ============================================================
-- TRAFFIC_SIGNAL
-- ============================================================
CREATE TABLE traffic_signal (
    signal_id           SERIAL          PRIMARY KEY,
    intersection_id     INT             NOT NULL UNIQUE REFERENCES intersection(intersection_id),
    current_phase       signal_phase    NOT NULL DEFAULT 'RED',
    green_duration_sec  SMALLINT        NOT NULL DEFAULT 30 CHECK (green_duration_sec > 0),
    yellow_duration_sec SMALLINT        NOT NULL DEFAULT 5  CHECK (yellow_duration_sec > 0),
    red_duration_sec    SMALLINT        NOT NULL DEFAULT 30 CHECK (red_duration_sec > 0),
    is_adaptive         BOOLEAN         NOT NULL DEFAULT FALSE,
    last_updated        TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SENSOR
-- ============================================================
CREATE TABLE sensor (
    sensor_id       SERIAL          PRIMARY KEY,
    sensor_type     sensor_type_enum NOT NULL,
    road_id         INT             NOT NULL REFERENCES road(road_id),
    location        GEOMETRY(POINT, 4326) NOT NULL,
    install_date    DATE            NOT NULL,
    status          VARCHAR(20)     NOT NULL DEFAULT 'ACTIVE',
    model_no        VARCHAR(50)
);

-- ============================================================
-- SENSOR_READING (partitioned by month — temporal)
-- ============================================================
CREATE TABLE sensor_reading (
    reading_id      BIGSERIAL,
    sensor_id       INT             NOT NULL REFERENCES sensor(sensor_id),
    reading_time    TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    speed_kmh       NUMERIC(5,2),
    vehicle_count   SMALLINT,
    occupancy_pct   NUMERIC(5,2),
    temperature_c   NUMERIC(4,1),
    PRIMARY KEY (reading_id, reading_time)
) PARTITION BY RANGE (reading_time);

-- Monthly partitions (example — 2025)
CREATE TABLE sensor_reading_2025_01 PARTITION OF sensor_reading
    FOR VALUES FROM ('2025-01-01') TO ('2025-02-01');
CREATE TABLE sensor_reading_2025_02 PARTITION OF sensor_reading
    FOR VALUES FROM ('2025-02-01') TO ('2025-03-01');
CREATE TABLE sensor_reading_2025_03 PARTITION OF sensor_reading
    FOR VALUES FROM ('2025-03-01') TO ('2025-04-01');
CREATE TABLE sensor_reading_2025_04 PARTITION OF sensor_reading
    FOR VALUES FROM ('2025-04-01') TO ('2025-05-01');

-- ============================================================
-- INCIDENT (Superclass — temporal: valid_from/valid_to)
-- ============================================================
CREATE TABLE incident (
    incident_id     SERIAL          PRIMARY KEY,
    category        incident_category NOT NULL,
    incident_time   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    resolved_time   TIMESTAMPTZ,
    reported_by     INT             REFERENCES person(person_id),
    severity        severity_level  NOT NULL DEFAULT 'MEDIUM',
    status          incident_status NOT NULL DEFAULT 'REPORTED',
    location        GEOMETRY(POINT, 4326) NOT NULL,
    road_id         INT             REFERENCES road(road_id),
    zone_id         INT             NOT NULL REFERENCES zone(zone_id),
    description     TEXT,
    -- Bi-temporal columns
    valid_from      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    valid_to        TIMESTAMPTZ     NOT NULL DEFAULT 'infinity',
    recorded_at     TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- Subclass: ACCIDENT
CREATE TABLE accident (
    incident_id         INT         PRIMARY KEY REFERENCES incident(incident_id) ON DELETE CASCADE,
    casualties          SMALLINT    NOT NULL DEFAULT 0,
    property_damage_usd NUMERIC(12,2),
    fault_vehicle_id    INT         REFERENCES vehicle(vehicle_id)
);

-- Subclass: CONGESTION
CREATE TABLE congestion (
    incident_id         INT         PRIMARY KEY REFERENCES incident(incident_id) ON DELETE CASCADE,
    affected_length_km  NUMERIC(6,2) NOT NULL,
    avg_speed_kmh       NUMERIC(5,2) NOT NULL,
    cause_type          VARCHAR(80)
);

-- Subclass: EMERGENCY_EVENT
CREATE TABLE emergency_event (
    incident_id             INT         PRIMARY KEY REFERENCES incident(incident_id) ON DELETE CASCADE,
    event_type              VARCHAR(80) NOT NULL,
    hazard_level            SMALLINT    NOT NULL DEFAULT 1 CHECK (hazard_level BETWEEN 1 AND 5),
    evacuation_required     BOOLEAN     NOT NULL DEFAULT FALSE,
    evacuation_zone_radius_m INT
);

-- ============================================================
-- EMERGENCY_UNIT
-- ============================================================
CREATE TABLE emergency_unit (
    unit_id             SERIAL          PRIMARY KEY,
    unit_type           VARCHAR(30)     NOT NULL,  -- 'AMBULANCE','FIRE_TRUCK','POLICE'
    agency_name         VARCHAR(100)    NOT NULL,
    vehicle_id          INT             UNIQUE REFERENCES emergency_vehicle(vehicle_id),
    current_location    GEOMETRY(POINT, 4326),
    availability_status unit_status     NOT NULL DEFAULT 'AVAILABLE',
    home_zone_id        INT             REFERENCES zone(zone_id),
    last_status_update  TIMESTAMPTZ     NOT NULL DEFAULT NOW()
);

-- ============================================================
-- DISPATCH (bridge: EMERGENCY_UNIT ↔ INCIDENT)
-- ============================================================
CREATE TABLE dispatch (
    dispatch_id     SERIAL          PRIMARY KEY,
    unit_id         INT             NOT NULL REFERENCES emergency_unit(unit_id),
    incident_id     INT             NOT NULL REFERENCES incident(incident_id),
    dispatch_time   TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    arrival_time    TIMESTAMPTZ,
    clear_time      TIMESTAMPTZ,
    notes           TEXT,
    CONSTRAINT uq_dispatch UNIQUE (unit_id, incident_id)
);

-- ============================================================
-- VEHICLE_INCIDENT (bridge: VEHICLE ↔ INCIDENT)
-- ============================================================
CREATE TABLE vehicle_incident (
    vehicle_id      INT     NOT NULL REFERENCES vehicle(vehicle_id),
    incident_id     INT     NOT NULL REFERENCES incident(incident_id),
    role            VARCHAR(30) NOT NULL DEFAULT 'INVOLVED',  -- 'INVOLVED','WITNESS','CAUSE'
    PRIMARY KEY (vehicle_id, incident_id)
);

-- ============================================================
-- VIOLATION
-- ============================================================
CREATE TABLE violation (
    violation_id        SERIAL          PRIMARY KEY,
    vehicle_id          INT             NOT NULL REFERENCES vehicle(vehicle_id),
    sensor_id           INT             NOT NULL REFERENCES sensor(sensor_id),
    violation_time      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    recorded_speed_kmh  NUMERIC(5,2)    NOT NULL,
    speed_limit_kmh     SMALLINT        NOT NULL,
    fine_amount_usd     NUMERIC(8,2)    NOT NULL DEFAULT 0,
    paid                BOOLEAN         NOT NULL DEFAULT FALSE
);

-- ============================================================
-- ROUTE
-- ============================================================
CREATE TABLE route (
    route_id            SERIAL          PRIMARY KEY,
    origin_zone_id      INT             NOT NULL REFERENCES zone(zone_id),
    dest_zone_id        INT             NOT NULL REFERENCES zone(zone_id),
    total_distance_km   NUMERIC(8,2)    NOT NULL,
    estimated_time_min  SMALLINT        NOT NULL,
    traffic_score       NUMERIC(3,1)    CHECK (traffic_score BETWEEN 0.0 AND 10.0),
    last_updated        TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_diff_zones CHECK (origin_zone_id <> dest_zone_id)
);

-- ============================================================
-- AUDIT_LOG (system-wide audit — temporal)
-- ============================================================
CREATE TABLE audit_log (
    log_id          BIGSERIAL       PRIMARY KEY,
    table_name      VARCHAR(60)     NOT NULL,
    operation       VARCHAR(10)     NOT NULL,  -- INSERT/UPDATE/DELETE
    record_id       INT             NOT NULL,
    changed_by      VARCHAR(60)     NOT NULL DEFAULT current_user,
    changed_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    old_values      JSONB,
    new_values      JSONB
);

-- ============================================================
-- OBJECT-RELATIONAL: COMPOSITE TYPES
-- ============================================================
CREATE TYPE address_type AS (
    street      VARCHAR(200),
    city        VARCHAR(100),
    state       VARCHAR(50),
    postal_code VARCHAR(20),
    country     VARCHAR(60)
);

CREATE TYPE contact_info_type AS (
    phone       VARCHAR(20),
    email       VARCHAR(200),
    alt_phone   VARCHAR(20)
);

-- Object-relational table using composite types
CREATE TABLE emergency_station (
    station_id      SERIAL          PRIMARY KEY,
    station_name    VARCHAR(150)    NOT NULL,
    station_type    VARCHAR(30)     NOT NULL,   -- 'FIRE','POLICE','AMBULANCE','UNIFIED'
    address         address_type,               -- Composite type attribute
    contact         contact_info_type,          -- Composite type attribute
    location        GEOMETRY(POINT, 4326),
    zone_id         INT             REFERENCES zone(zone_id),
    capacity        SMALLINT        NOT NULL DEFAULT 10,
    active          BOOLEAN         NOT NULL DEFAULT TRUE
);

-- ============================================================
-- INDEXES
-- ============================================================
CREATE INDEX idx_incident_location    ON incident USING GIST(location);
CREATE INDEX idx_incident_time        ON incident(incident_time DESC);
CREATE INDEX idx_incident_status      ON incident(status) WHERE status NOT IN ('RESOLVED','CLOSED');
CREATE INDEX idx_sensor_reading_time  ON sensor_reading(reading_time DESC);
CREATE INDEX idx_sensor_reading_sensor ON sensor_reading(sensor_id, reading_time DESC);
CREATE INDEX idx_road_geom            ON road USING GIST(road_geom);
CREATE INDEX idx_zone_boundary        ON zone USING GIST(boundary);
CREATE INDEX idx_eu_location          ON emergency_unit USING GIST(current_location);
CREATE INDEX idx_vehicle_plate        ON vehicle(license_plate);
CREATE INDEX idx_violation_vehicle    ON violation(vehicle_id, violation_time DESC);
CREATE INDEX idx_dispatch_incident    ON dispatch(incident_id);
CREATE INDEX idx_audit_table_rec      ON audit_log(table_name, record_id, changed_at DESC);
