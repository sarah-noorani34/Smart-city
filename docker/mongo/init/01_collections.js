// ============================================================
// MongoDB Init Script — Smart City DB
// Runs automatically on first container startup
// ============================================================

db = db.getSiblingDB('smart_city_db');

// ── Collection 1: sensor_logs ────────────────────────────────
db.createCollection("sensor_logs");
db.sensor_logs.createIndex({ "sensor_meta.location": "2dsphere" });
db.sensor_logs.createIndex({ "sensor_meta.sensor_id": 1, "timestamp": -1 });

db.sensor_logs.insertMany([
  {
    timestamp: new Date(Date.now() - 600000),
    sensor_meta: { sensor_id: "SNS-1042", sensor_type: "SPEED", road_id: 1, zone: "CENTRAL_HIGHWAY",
      location: { type: "Point", coordinates: [67.048, 24.868] } },
    speed_kmh: 87.4, vehicle_count: 14, occupancy_pct: 62.5, temperature_c: 33.1, quality_flag: "OK"
  },
  {
    timestamp: new Date(Date.now() - 300000),
    sensor_meta: { sensor_id: "SNS-1042", sensor_type: "SPEED", road_id: 1, zone: "CENTRAL_HIGHWAY",
      location: { type: "Point", coordinates: [67.048, 24.868] } },
    speed_kmh: 92.1, vehicle_count: 10, occupancy_pct: 55.0, temperature_c: 33.3, quality_flag: "OK"
  },
  {
    timestamp: new Date(Date.now() - 120000),
    sensor_meta: { sensor_id: "SNS-2015", sensor_type: "INDUCTIVE_LOOP", road_id: 1, zone: "CENTRAL_HIGHWAY",
      location: { type: "Point", coordinates: [67.050, 24.870] } },
    speed_kmh: 45.2, vehicle_count: 34, occupancy_pct: 85.0, temperature_c: 33.0, quality_flag: "OK"
  },
  {
    timestamp: new Date(Date.now() - 60000),
    sensor_meta: { sensor_id: "SNS-3001", sensor_type: "SPEED", road_id: 2, zone: "EAST_COMMERCIAL",
      location: { type: "Point", coordinates: [67.060, 24.865] } },
    speed_kmh: 127.5, vehicle_count: 1, occupancy_pct: 5.0, temperature_c: 33.5, quality_flag: "VIOLATION"
  }
]);

// ── Collection 2: incident_events ───────────────────────────
db.createCollection("incident_events");
db.incident_events.createIndex({ "incident_id": 1, "timestamp": -1 });
db.incident_events.createIndex({ "location": "2dsphere" });
db.incident_events.createIndex({ "category": 1, "new_state": 1 });

db.incident_events.insertMany([
  {
    event_id: "EVT-20260408-0001",
    incident_id: 1, category: "ACCIDENT", event_type: "INCIDENT_CREATED",
    new_state: "REPORTED", previous_state: null, severity: "CRITICAL",
    location: { type: "Point", coordinates: [67.051, 24.873] },
    zone: "CENTRAL_HIGHWAY",
    timestamp: new Date(Date.now() - 900000),
    actor: { user_id: "CITIZEN-001", role: "CITIZEN", station: null },
    metadata: { source: "MOBILE_APP", ip_addr: "10.20.30.40" }
  },
  {
    event_id: "EVT-20260408-0002",
    incident_id: 1, category: "ACCIDENT", event_type: "STATUS_CHANGED",
    new_state: "DISPATCHED", previous_state: "REPORTED", severity: "CRITICAL",
    location: { type: "Point", coordinates: [67.051, 24.873] },
    zone: "CENTRAL_HIGHWAY",
    timestamp: new Date(Date.now() - 840000),
    actor: { user_id: "AUTO_SYSTEM", role: "TRIGGER", station: "DB_NODE_1" },
    dispatched_units: [
      { unit_id: "AMB-021", unit_type: "AMBULANCE", eta_min: 4 },
      { unit_id: "POL-117", unit_type: "POLICE",    eta_min: 3 }
    ],
    metadata: { source: "AUTO_TRIGGER", ip_addr: "127.0.0.1" }
  },
  {
    event_id: "EVT-20260408-0003",
    incident_id: 2, category: "CONGESTION", event_type: "INCIDENT_CREATED",
    new_state: "REPORTED", previous_state: null, severity: "HIGH",
    location: { type: "Point", coordinates: [67.040, 24.866] },
    zone: "CENTRAL_HIGHWAY",
    timestamp: new Date(Date.now() - 800000),
    actor: { user_id: "SNS-5001", role: "AUTO_SENSOR", station: "SENSOR_NODE" },
    metadata: { source: "SENSOR_DETECT", ip_addr: "10.10.5.44" }
  }
]);

// ── Collection 3: vehicle_gps_tracks ────────────────────────
db.createCollection("vehicle_gps_tracks");
db.vehicle_gps_tracks.createIndex({ "vehicle_id": 1, "trip_date": -1 });
db.vehicle_gps_tracks.createIndex({ "waypoints.coords": "2dsphere" });
db.vehicle_gps_tracks.createIndex({ "incident_id": 1 });

db.vehicle_gps_tracks.insertOne({
  track_id: "TRK-20260408-AMB021",
  vehicle_id: "VH-4", unit_code: "AMB-021", vehicle_type: "AMBULANCE",
  trip_date: new Date(), trip_start: new Date(Date.now() - 840000), trip_end: null,
  waypoints: [
    { seq: 1, timestamp: new Date(Date.now() - 840000), coords: { type: "Point", coordinates: [67.046, 24.865] }, speed_kmh: 0,    heading_deg: 0   },
    { seq: 2, timestamp: new Date(Date.now() - 810000), coords: { type: "Point", coordinates: [67.048, 24.867] }, speed_kmh: 55.0, heading_deg: 45  },
    { seq: 3, timestamp: new Date(Date.now() - 780000), coords: { type: "Point", coordinates: [67.050, 24.870] }, speed_kmh: 72.0, heading_deg: 50  },
    { seq: 4, timestamp: new Date(Date.now() - 750000), coords: { type: "Point", coordinates: [67.051, 24.872] }, speed_kmh: 60.0, heading_deg: 55  }
  ],
  incident_id: 1, distance_km: null, avg_speed_kmh: null, status: "ACTIVE"
});

// ── Collection 4: alert_notifications ───────────────────────
db.createCollection("alert_notifications");
db.alert_notifications.createIndex({ "issued_at": -1 });
db.alert_notifications.createIndex({ "geofence": "2dsphere" });

db.alert_notifications.insertOne({
  alert_id: "ALT-20260408-0001",
  alert_type: "ROAD_CLOSURE", severity: "HIGH",
  issued_at: new Date(Date.now() - 820000),
  expires_at: new Date(Date.now() + 14400000),
  incident_id: 1, affected_roads: [1, 5], affected_zones: ["CENTRAL_HIGHWAY"],
  message: "Road closure on Sharea Faisal due to major accident. Use Korangi Road as alternative.",
  channels: ["SMS", "PUSH", "DIGITAL_SIGNBOARD"],
  recipients: { total_sent: 1842, acknowledged: 903, failed: 12 },
  geofence: { type: "Point", coordinates: [67.051, 24.873] },
  geofence_radius_m: 2000, created_by: "AUTO_SYSTEM"
});

// ── Collection 5: system_audit_trail ────────────────────────
db.createCollection("system_audit_trail");
db.system_audit_trail.createIndex({ "timestamp": -1 });
db.system_audit_trail.createIndex({ "user.user_id": 1, "timestamp": -1 });

db.system_audit_trail.insertMany([
  {
    audit_id: "AUD-20260408-00001",
    timestamp: new Date(Date.now() - 900000),
    service: "INCIDENT_SERVICE", action: "INSERT", collection: "incident_events",
    document_id: "EVT-20260408-0001",
    user: { user_id: "CITIZEN-001", username: "amir.raza", ip_address: "10.20.30.40", role: "CITIZEN" },
    request_id: "req_abc123", success: true, duration_ms: 6
  },
  {
    audit_id: "AUD-20260408-00002",
    timestamp: new Date(Date.now() - 840000),
    service: "DISPATCH_SERVICE", action: "INSERT", collection: "incident_events",
    document_id: "EVT-20260408-0002",
    user: { user_id: "AUTO_SYSTEM", username: "trigger_user", ip_address: "127.0.0.1", role: "SYSTEM" },
    request_id: "req_def456", success: true, duration_ms: 4
  }
]);

print("✓ MongoDB collections created and seeded successfully");
print("  Collections: sensor_logs, incident_events, vehicle_gps_tracks, alert_notifications, system_audit_trail");
