-- ============================================================
-- Step 1: Enable required PostgreSQL extensions
-- Runs automatically on first container startup
-- ============================================================
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- Confirm
SELECT PostGIS_Version();
