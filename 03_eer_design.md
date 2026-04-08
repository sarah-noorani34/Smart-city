# 3. EER Design

## Entities and Attributes

### Superclass: PERSON
- PersonID (PK), FullName, DateOfBirth, ContactNumber, Email, Address

  #### Subclass: DRIVER            (Specialization — OVERLAPPING, PARTIAL)
  - LicenseNumber, LicenseExpiry, DemeritPoints

  #### Subclass: EMERGENCY_RESPONDER  (Specialization — OVERLAPPING, PARTIAL)
  - BadgeNumber, Specialization, ShiftStart, ShiftEnd

  #### Subclass: TRAFFIC_OFFICER      (Specialization — OVERLAPPING, PARTIAL)
  - StationID, Jurisdiction, Rank

---

### Superclass: VEHICLE
- VehicleID (PK), LicensePlate, Make, Model, Year, Color, OwnerID (FK→PERSON)

  #### Subclass: PRIVATE_VEHICLE      (Specialization — DISJOINT, TOTAL)
  - RegistrationExpiry, InsurancePolicyNo

  #### Subclass: PUBLIC_VEHICLE       (Specialization — DISJOINT, TOTAL)
  - RouteNumber, OperatorID, Capacity

  #### Subclass: EMERGENCY_VEHICLE    (Specialization — DISJOINT, TOTAL)
  - UnitCode, AgencyName, EquipmentList

---

### Superclass: INCIDENT
- IncidentID (PK), IncidentTime, ReportedBy (FK→PERSON), SeverityLevel,
  Status, Location (POINT), Description

  #### Subclass: ACCIDENT             (Specialization — DISJOINT, TOTAL)
  - Casualties, PropertyDamage, FaultVehicleID (FK→VEHICLE)

  #### Subclass: CONGESTION           (Specialization — DISJOINT, TOTAL)
  - AffectedLength_km, AvgSpeedKmh, CauseType

  #### Subclass: EMERGENCY_EVENT      (Specialization — DISJOINT, TOTAL)
  - EventType, HazardLevel, EvacuationRequired

---

### Other Entities

- **ROAD**         : RoadID (PK), RoadName, RoadType, SpeedLimit, Lanes,
                     StartPoint (GEOMETRY), EndPoint (GEOMETRY), ZoneID (FK)

- **INTERSECTION** : IntersectionID (PK), Location (POINT), RoadID1 (FK), RoadID2 (FK)

- **TRAFFIC_SIGNAL**: SignalID (PK), IntersectionID (FK), CurrentPhase,
                      GreenDuration, RedDuration, LastUpdated, IsAdaptive

- **SENSOR**       : SensorID (PK), SensorType, Location (POINT), RoadID (FK),
                     InstallDate, Status

- **SENSOR_READING**: ReadingID (PK), SensorID (FK), ReadingTime, SpeedKmh,
                      VehicleCount, Occupancy_pct

- **ZONE**         : ZoneID (PK), ZoneName, ZoneType, Boundary (POLYGON)

- **EMERGENCY_UNIT**: UnitID (PK), UnitType, AgencyName, CurrentLocation (POINT),
                      AvailabilityStatus, VehicleID (FK→EMERGENCY_VEHICLE)

- **DISPATCH**     : DispatchID (PK), UnitID (FK), IncidentID (FK),
                     DispatchTime, ArrivalTime, ClearTime

- **ROUTE**        : RouteID (PK), OriginZoneID (FK), DestZoneID (FK),
                     TotalDistance_km, EstimatedTime_min, TrafficScore

- **VIOLATION**    : ViolationID (PK), VehicleID (FK), SensorID (FK),
                     ViolationTime, RecordedSpeed, SpeedLimit, FineAmount

---

## Relationships

| Relationship         | Entities                        | Cardinality | Participation     |
|----------------------|---------------------------------|-------------|-------------------|
| DRIVES               | DRIVER → VEHICLE                | 1 : N       | Partial : Partial |
| OWNS                 | PERSON → VEHICLE                | 1 : N       | Partial : Total   |
| INVOLVES             | VEHICLE ↔ INCIDENT              | M : N       | Partial : Partial |
| RESPONDS_TO          | EMERGENCY_UNIT ↔ INCIDENT       | M : N (via DISPATCH) | Total : Partial |
| MONITORS             | SENSOR → ROAD                   | N : 1       | Total : Partial   |
| CONTROLS             | TRAFFIC_SIGNAL → INTERSECTION   | 1 : 1       | Total : Total     |
| LOCATED_IN           | ROAD → ZONE                     | N : 1       | Total : Total     |
| CONNECTS             | ROAD ↔ INTERSECTION             | M : N       | Partial : Total   |
| GENERATES            | SENSOR → SENSOR_READING         | 1 : N       | Partial : Total   |
| ASSIGNED_TO          | EMERGENCY_UNIT → ZONE           | N : 1       | Partial : Partial |

---

## EER Diagram (ASCII)

```
                    PERSON
                   /   |   \
          (d,p) Specialization
                /     |     \
          DRIVER  EM_RESP  TRAFFIC_OFFICER

                    VEHICLE
                   /   |    \
          (d,t) Specialization
               /      |      \
        PRIVATE   PUBLIC    EMERGENCY_VEHICLE
                                   |
                            EMERGENCY_UNIT

                    INCIDENT
                   /    |    \
          (d,t) Specialization
               /       |       \
         ACCIDENT  CONGESTION  EMERGENCY_EVENT

ZONE ──< ROAD >──< INTERSECTION >── TRAFFIC_SIGNAL
          |
        SENSOR ──> SENSOR_READING
                        |
                    VIOLATION
```

**Legend:** (d,t) = Disjoint-Total  |  (o,p) = Overlapping-Partial
