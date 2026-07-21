-- ============================================================================
-- Phase 0 — unblock multi-simulation support
--
-- Goal: allow a second simulation (Meridian Retail QBR) to coexist with
-- Simulation 1 (Leadership Judgment / ANP Phoenix) WITHOUT changing Sim-1
-- behaviour. Every change here is backward compatible: existing teams are
-- backfilled to Sim 1, and the Sim-1 role list is seeded exactly as it was
-- previously hardcoded in TeamService.getRoles().
--
-- Apply with:
--   psql -h localhost -U simulator_user -d simulator_db -f V1__phase0_multisim.sql
-- Idempotent: safe to re-run.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Per-simulation role definitions
--    Replaces the hardcoded role list in TeamService. `is_lead` marks the role
--    that (a) the team creator is auto-assigned and (b) may submit the final /
--    per-round decision. Sim 1 => CEO. Sim 2 => Team Lead.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS simulation_roles (
    simulation_id UUID    NOT NULL,
    role_code     TEXT    NOT NULL,
    display_name  TEXT    NOT NULL,
    ordinal       INTEGER NOT NULL,
    is_lead       BOOLEAN NOT NULL DEFAULT false,
    CONSTRAINT pk_simulation_roles PRIMARY KEY (simulation_id, role_code)
);

CREATE INDEX IF NOT EXISTS idx_simulation_roles_sim_ordinal
    ON simulation_roles (simulation_id, ordinal);

-- Exactly one lead role per simulation.
CREATE UNIQUE INDEX IF NOT EXISTS uq_simulation_roles_one_lead
    ON simulation_roles (simulation_id) WHERE is_lead;

-- ---------------------------------------------------------------------------
-- 2. Seed Simulation 1 roles — must match the previously hardcoded list in
--    TeamService.getRoles() exactly, or Sim 1 role selection breaks.
--    Previous list: CEO, CFO, HEAD_OF_ENGINEERING, PRODUCT, OPERATIONS, CHRO
-- ---------------------------------------------------------------------------
INSERT INTO simulation_roles (simulation_id, role_code, display_name, ordinal, is_lead)
VALUES
    ('475db739-0708-48d4-b4db-5a23f1da50d9', 'CEO',                 'CEO',                  1, true),
    ('475db739-0708-48d4-b4db-5a23f1da50d9', 'CFO',                 'CFO',                  2, false),
    ('475db739-0708-48d4-b4db-5a23f1da50d9', 'HEAD_OF_ENGINEERING', 'Head of Engineering',  3, false),
    ('475db739-0708-48d4-b4db-5a23f1da50d9', 'PRODUCT',             'Head of Product',      4, false),
    ('475db739-0708-48d4-b4db-5a23f1da50d9', 'OPERATIONS',          'Head of Operations',   5, false),
    ('475db739-0708-48d4-b4db-5a23f1da50d9', 'CHRO',                'CHRO',                 6, false)
ON CONFLICT (simulation_id, role_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3. Tag teams with the simulation they are playing.
--    NOTE: the JPA-managed table is singular `team` (not `teams`).
--    Nullable + backfilled so existing Sim-1 teams keep working.
-- ---------------------------------------------------------------------------
ALTER TABLE team ADD COLUMN IF NOT EXISTS simulation_id UUID;

UPDATE team
   SET simulation_id = '475db739-0708-48d4-b4db-5a23f1da50d9'
 WHERE simulation_id IS NULL;

CREATE INDEX IF NOT EXISTS idx_team_simulation ON team (simulation_id);

COMMIT;

-- ---------------------------------------------------------------------------
-- Verification
-- ---------------------------------------------------------------------------
-- SELECT simulation_id, role_code, ordinal, is_lead FROM simulation_roles ORDER BY simulation_id, ordinal;
-- SELECT team_id, team_name, simulation_id FROM team;
