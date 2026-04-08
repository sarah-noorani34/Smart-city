// ============================================================
// 5. MONGODB DESIGN
//    Database: smart_city_db
//    Purpose : High-volume sensor logs, event streams,
//              real-time GPS tracks, audit trails, alerts
// ============================================================

// ── Collection 1: sensor_logs ────────────────────────────────
// Stores raw IoT sensor readings at high write throughput.
// Time-series oriented; capped / TTL index after 90 days.

db.createCollection("sensor_logs", {
  timeseries: {
    timeField:   "timestamp",
    metaField:   "sensor_meta",
    granularity: "seconds"
  },
  expireAfterSeconds: 7776000   // 90 days TTL
});

// Sample document — sensor_logs
db.sensor_logs.insertOne({
  timestamp: ISODate("2025-04-08T14:22:05Z"),
  sensor_meta: {
    sensor_id:   "SNS-1042",
    sensor_type: "SPEED",
    road_id:     301,
    zone:        "NORTH_COMMERCIAL",
    location: {
      type:        "Point",
      coordinates: [67.0833, 24.8607]   // [longitude, latitude] — Karachi
    }
  },
  speed_kmh:      87.4,
  vehicle_count:  14,
  occupancy_pct:  62.5,
  temperature_c:  33.1,
  raw_payload:    "SNS1042|20250408T142205|87.4|14|62.5",
  quality_flag:   "OK"
});

// Index for geo-queries on sensor location
db.sensor_logs.createIndex({ "sensor_meta.location": "2dsphere" });
db.sensor_logs.createIndex({ "sensor_meta.sensor_id": 1, "timestamp": -1 });

// ── Collection 2: incident_events ───────────────────────────
// Event-sourced log of every state transition for an incident.
// Immutable append-only; full history preserved.

db.createCollection("incident_events");

// Sample document — incident_events
db.incident_events.insertOne({
  event_id:      "EVT-20250408-0047",
  incident_id:   4821,                     // FK mirror to PostgreSQL
  category:      "ACCIDENT",
  event_type:    "STATUS_CHANGED",
  previous_state: "REPORTED",
  new_state:     "DISPATCHED",
  severity:      "HIGH",
  location: {
    type:        "Point",
    coordinates: [67.0512, 24.8732]
  },
  zone:          "CENTRAL_HIGHWAY",
  timestamp:     ISODate("2025-04-08T14:23:10Z"),
  actor: {
    user_id:     "OPS-007",
    role:        "DISPATCH_OPERATOR",
    station:     "CTRL-NORTH"
  },
  dispatched_units: [
    { unit_id: "AMB-021", unit_type: "AMBULANCE",  eta_min: 4 },
    { unit_id: "POL-117", unit_type: "POLICE",     eta_min: 3 }
  ],
  metadata: {
    source:    "DISPATCH_CONSOLE",
    ip_addr:   "10.10.5.44",
    session:   "sess_8fa3c2"
  }
});

db.incident_events.createIndex({ "incident_id": 1, "timestamp": -1 });
db.incident_events.createIndex({ "location": "2dsphere" });
db.incident_events.createIndex({ "category": 1, "new_state": 1 });

// ── Collection 3: vehicle_gps_tracks ────────────────────────
// Continuous GPS tracking for fleet vehicles and emergency units.
// One document per vehicle per trip.

db.createCollection("vehicle_gps_tracks");

// Sample document — vehicle_gps_tracks
db.vehicle_gps_tracks.insertOne({
  track_id:    "TRK-20250408-AMB021",
  vehicle_id:  "VH-2041",
  unit_code:   "AMB-021",
  vehicle_type:"AMBULANCE",
  trip_date:   ISODate("2025-04-08T00:00:00Z"),
  trip_start:  ISODate("2025-04-08T14:23:12Z"),
  trip_end:    null,                        // null = ongoing
  waypoints: [
    {
      seq:        1,
      timestamp:  ISODate("2025-04-08T14:23:12Z"),
      coords: { type: "Point", coordinates: [67.0622, 24.8801] },
      speed_kmh:  0,
      heading_deg: 0
    },
    {
      seq:        2,
      timestamp:  ISODate("2025-04-08T14:23:30Z"),
      coords: { type: "Point", coordinates: [67.0618, 24.8795] },
      speed_kmh:  42.3,
      heading_deg: 185
    },
    {
      seq:        3,
      timestamp:  ISODate("2025-04-08T14:24:00Z"),
      coords: { type: "Point", coordinates: [67.0589, 24.8771] },
      speed_kmh:  68.0,
      heading_deg: 190
    }
  ],
  incident_id:     4821,
  distance_km:     null,
  avg_speed_kmh:   null,
  status:          "ACTIVE"
});

db.vehicle_gps_tracks.createIndex({ "vehicle_id": 1, "trip_date": -1 });
db.vehicle_gps_tracks.createIndex({ "waypoints.coords": "2dsphere" });
db.vehicle_gps_tracks.createIndex({ "incident_id": 1 });

// ── Collection 4: alert_notifications ───────────────────────
// System-generated alerts sent to operators, officers, and public.

db.createCollection("alert_notifications");

// Sample document — alert_notifications
db.alert_notifications.insertOne({
  alert_id:    "ALT-20250408-3391",
  alert_type:  "ROAD_CLOSURE",
  severity:    "HIGH",
  issued_at:   ISODate("2025-04-08T14:24:00Z"),
  expires_at:  ISODate("2025-04-08T18:00:00Z"),
  incident_id: 4821,
  affected_roads: [301, 302],
  affected_zones: ["CENTRAL_HIGHWAY", "NORTH_COMMERCIAL"],
  message:     "Road closure on Main Sharea Faisal due to major accident. Use alternative routes.",
  channels: ["SMS", "PUSH", "DIGITAL_SIGNBOARD"],
  recipients: {
    total_sent:     1842,
    acknowledged:   903,
    failed:         12
  },
  geofence: {
    type:   "Point",
    coordinates: [67.0512, 24.8732]
  },
  geofence_radius_m: 2000,
  created_by:  "AUTO_SYSTEM"
});

db.alert_notifications.createIndex({ "issued_at": -1 });
db.alert_notifications.createIndex({ "geofence": "2dsphere" });
db.alert_notifications.createIndex({ "alert_type": 1, "severity": 1 });

// ── Collection 5: system_audit_trail ────────────────────────
// Security and compliance audit log for all DB write operations.

db.createCollection("system_audit_trail");

// Sample document — system_audit_trail
db.system_audit_trail.insertOne({
  audit_id:    "AUD-20250408-00884",
  timestamp:   ISODate("2025-04-08T14:22:55Z"),
  service:     "DISPATCH_SERVICE",
  action:      "INSERT",
  collection:  "incident_events",
  document_id: "EVT-20250408-0047",
  user: {
    user_id:   "OPS-007",
    username:  "raheem.khan",
    ip_address:"10.10.5.44",
    role:      "DISPATCH_OPERATOR"
  },
  request_id:  "req_9a3f7b",
  success:     true,
  duration_ms: 4
});

db.system_audit_trail.createIndex({ "timestamp": -1 });
db.system_audit_trail.createIndex({ "user.user_id": 1, "timestamp": -1 });
db.system_audit_trail.createIndex({ "action": 1, "collection": 1 });

// ── Aggregation Pipeline Example ────────────────────────────
// Count high-severity incidents per zone in last 24 hours

db.incident_events.aggregate([
  {
    $match: {
      severity:  { $in: ["HIGH", "CRITICAL"] },
      timestamp: { $gte: new Date(Date.now() - 86400000) },
      event_type: "STATUS_CHANGED",
      new_state: "REPORTED"
    }
  },
  {
    $group: {
      _id:   "$zone",
      count: { $sum: 1 },
      latest_incident: { $max: "$timestamp" }
    }
  },
  { $sort: { count: -1 } },
  { $limit: 10 },
  {
    $project: {
      zone:             "$_id",
      incident_count:   "$count",
      last_occurrence:  "$latest_incident",
      _id: 0
    }
  }
]);
