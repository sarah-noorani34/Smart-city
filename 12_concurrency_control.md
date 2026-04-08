# 12. Concurrency Control

## Overview

The system uses **Multi-Version Concurrency Control (MVCC)** as implemented by PostgreSQL,
supplemented by explicit locking for critical dispatch operations.

---

## MVCC — How PostgreSQL Handles It

PostgreSQL never overwrites data in place. Every `UPDATE` creates a new row version
(`tuple`) tagged with the transaction's `xmin` (created-by) and `xmax` (deleted-by)
transaction IDs. Readers see a consistent snapshot of the database at the moment their
transaction started — they never block writers, and writers never block readers.

```
Timeline:  T1 = txid 1001    T2 = txid 1002    T3 = txid 1003
           (Dispatch unit)    (Read incident)   (Update signal)

T1 BEGIN;
T1: UPDATE emergency_unit SET availability_status='DISPATCHED' WHERE unit_id=21;
  → New tuple: (unit_id=21, xmin=1001, xmax=0, status='DISPATCHED')
  → Old tuple: (unit_id=21, xmin=999,  xmax=1001, status='AVAILABLE')

T2 BEGIN;  -- starts AFTER T1 BEGIN but BEFORE T1 COMMIT
T2: SELECT * FROM emergency_unit WHERE unit_id=21;
  → T2 sees OLD tuple (xmax=1001 > T2.snapshot) → reads 'AVAILABLE'
  → T2 is NOT blocked by T1's ongoing UPDATE

T1 COMMIT;  -- xid 1001 committed

T3 BEGIN;   -- starts AFTER T1 COMMIT
T3: SELECT * FROM emergency_unit WHERE unit_id=21;
  → T3 sees NEW tuple (xmin=1001, committed) → reads 'DISPATCHED'
```

**Isolation level used:** `READ COMMITTED` (default) for sensor writes;
`REPEATABLE READ` for dispatch operations to prevent phantom reads.

---

## Explicit Locking — Dispatch Race Condition Prevention

**Problem:** Two operators simultaneously try to dispatch the same unit to different incidents.

```
Operator A:  SELECT unit WHERE unit_id=21 AND status='AVAILABLE';  → gets unit 21
Operator B:  SELECT unit WHERE unit_id=21 AND status='AVAILABLE';  → also gets unit 21
Operator A:  UPDATE emergency_unit SET status='DISPATCHED' ... unit_id=21;
Operator B:  UPDATE emergency_unit SET status='DISPATCHED' ... unit_id=21;  -- DOUBLE DISPATCH!
```

**Solution:** `SELECT ... FOR UPDATE SKIP LOCKED` in the dispatch procedure.

```sql
-- Inside sp_dispatch_nearest_unit (critical section)
BEGIN;
  SELECT unit_id, agency_name, current_location
  FROM   emergency_unit
  WHERE  availability_status = 'AVAILABLE'
    AND  unit_type = 'AMBULANCE'
  ORDER BY ST_Distance(current_location::geography,
            (SELECT location::geography FROM incident WHERE incident_id = 4821))
  LIMIT  1
  FOR UPDATE SKIP LOCKED;   -- ← locks the row; skips if another txn holds it
                              --   prevents double-dispatch without deadlocking

  -- If row found: update status and insert dispatch
  UPDATE emergency_unit SET availability_status = 'DISPATCHED' WHERE unit_id = <found_id>;
  INSERT INTO dispatch (...) VALUES (...);
COMMIT;
```

`SKIP LOCKED` means Operator B's query simply moves to the next available unit rather
than waiting — no deadlock, no double booking.

---

## Deadlock Example and Prevention

**Potential deadlock:**
```
T1: LOCK TABLE incident → then tries to LOCK TABLE dispatch
T2: LOCK TABLE dispatch → then tries to LOCK TABLE incident
→ Circular wait → PostgreSQL detects and aborts one transaction
```

**Prevention strategies used:**

| Strategy                  | Implementation                                                   |
|---------------------------|------------------------------------------------------------------|
| Consistent lock ordering  | Always lock `incident` before `dispatch` in all procedures      |
| Row-level locking         | `SELECT FOR UPDATE` instead of table locks wherever possible     |
| Short transactions        | Dispatch procedure commits within < 100 ms                       |
| Deadlock detection        | PostgreSQL auto-detects; `deadlock_timeout = 1s` (config)        |
| Retry logic               | Application layer retries on `SQLSTATE 40P01` (deadlock_detected)|

---

## Isolation Levels by Operation

| Operation                     | Isolation Level       | Reason                                       |
|-------------------------------|-----------------------|----------------------------------------------|
| Sensor reading INSERT         | READ COMMITTED        | High throughput; stale reads acceptable      |
| Incident status query (UI)    | READ COMMITTED        | Near-real-time display; snapshot fine        |
| Dispatch unit assignment      | REPEATABLE READ       | Must not see phantom units mid-transaction   |
| Violation fine INSERT         | READ COMMITTED        | Independent records; no phantom risk         |
| Signal timing optimization    | REPEATABLE READ       | Consistent sensor aggregate during proc      |
| Audit log INSERT              | READ COMMITTED        | Append-only; no conflict                     |
| Bi-temporal incident update   | SERIALIZABLE          | Strict history integrity; no overlapping     |

---

## Two-Phase Locking (2PL) — Conceptual Mapping

Although PostgreSQL uses MVCC (not strict 2PL), the dispatch procedure
logically follows 2PL:

```
Growing Phase:
  ACQUIRE lock on emergency_unit(unit_id=21)   ← SELECT FOR UPDATE
  ACQUIRE lock on incident(incident_id=4821)   ← implicit on UPDATE
  ACQUIRE lock on dispatch (new row)            ← INSERT

Lock Point reached — all needed locks held.

Shrinking Phase:
  RELEASE all locks on COMMIT
```

This guarantees serializability for the dispatch transaction.
