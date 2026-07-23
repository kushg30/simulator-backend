-- ============================================================================
-- Phase 2 — Faculty Control Layer (PLATFORM-LEVEL)
--
-- This layer is shared by EVERY simulation: Simulation 1 (Leadership Judgment),
-- Simulator 2 (Meridian Retail QBR) and anything added later. Nothing here is
-- prefixed sim2_, and nothing here references a specific simulation's tables.
--
-- The source spec is explicit that this is general platform feedback that
-- "applies to every simulation on the platform, not specific to this one".
--
-- Capabilities: pause/resume, delay, bypass, artifact injection (catalogue and
-- on-the-fly), and a facilitator action log.
--
-- Apply with:
--   psql -h 127.0.0.1 -U postgres -d simulator_db -f V4__faculty_control_layer.sql
-- Idempotent: safe to re-run.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. The run clock — simulation-agnostic.
--
-- Any engine can LEFT JOIN this to shift its artifact timings. It replaces the
-- Sim-2-only sim2_round_state.paused_seconds_total, which could not serve
-- Simulation 1 or future simulators.
--
-- round_number is NULL for simulations that run a single clock for the whole
-- run (Simulation 1) and set for per-round clocks (Simulator 2).
--
-- Semantics:
--   paused_seconds_total  accumulated completed pauses
--   paused_at             non-null while a pause is IN PROGRESS
--
-- Effective elapsed time therefore excludes both, which is what freezes
-- artifact releases mid-pause instead of letting them fire.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS run_round_clock (
    run_id               UUID    NOT NULL,
    round_number         INTEGER NOT NULL DEFAULT 0,   -- 0 = whole-run clock
    paused_seconds_total INTEGER NOT NULL DEFAULT 0 CHECK (paused_seconds_total >= 0),
    paused_at            TIMESTAMP,
    updated_at           TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT pk_run_round_clock PRIMARY KEY (run_id, round_number)
);

-- ---------------------------------------------------------------------------
-- 2. Facilitator action log.
--
-- Every control action is persisted, not just executed. This is what makes the
-- active-time maths and the bypass/rollup exclusion defensible, and it is the
-- record a facilitator needs if a team later disputes a score.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS faculty_actions (
    action_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    simulation_id    UUID,
    run_id           UUID,
    team_id          UUID,
    round_number     INTEGER,
    action_type      TEXT NOT NULL CHECK (action_type IN
                          ('PAUSE','RESUME','DELAY','BYPASS','INJECT')),
    scope            TEXT NOT NULL CHECK (scope IN ('ALL','TEAM')),
    target_artifact  UUID,
    delay_minutes    INTEGER,
    injected_content JSONB,
    note             TEXT,
    created_by       TEXT,
    created_at       TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_faculty_actions_run ON faculty_actions (run_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- 3. Per-run artifact overrides (delay / bypass).
--
-- Keyed by artifact so it works for any simulation's authored artifacts.
-- A bypassed artifact never appears and its conditional trigger never fires;
-- a bypassed ROUND is recorded in run_round_bypass below.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS run_artifact_overrides (
    run_id        UUID    NOT NULL,
    artifact_id   UUID    NOT NULL,
    delay_minutes INTEGER NOT NULL DEFAULT 0,
    bypassed      BOOLEAN NOT NULL DEFAULT false,
    updated_at    TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT pk_run_artifact_overrides PRIMARY KEY (run_id, artifact_id)
);

-- A bypassed round is excluded from the construct rollup, NOT scored as zero.
CREATE TABLE IF NOT EXISTS run_round_bypass (
    run_id       UUID    NOT NULL,
    round_number INTEGER NOT NULL,
    reason       TEXT,
    created_at   TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT pk_run_round_bypass PRIMARY KEY (run_id, round_number)
);

-- ---------------------------------------------------------------------------
-- 4. Catalogue artifacts — pre-authored, pre-vetted, injectable live.
--
-- Only catalogue entries may be SCORED, because the answer key already holds a
-- canonical answer for them. On-the-fly injections are context-only unless the
-- facilitator supplies a canonical answer at the moment of injection, in which
-- case it is flagged as an ad hoc override in the action log.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS catalogue_artifacts (
    catalogue_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    simulation_id    UUID    NOT NULL,
    round_number     INTEGER NOT NULL,
    title            TEXT    NOT NULL,
    content          TEXT    NOT NULL,
    tier             TEXT    NOT NULL CHECK (tier IN ('CONTEXT','SCORED')),
    canonical_answer TEXT,
    effect           TEXT,
    CONSTRAINT ck_catalogue_scored_needs_answer CHECK (
        tier = 'CONTEXT' OR canonical_answer IS NOT NULL
    )
);

-- Artifacts pushed into a live run (from the catalogue or free-form).
CREATE TABLE IF NOT EXISTS run_injected_artifacts (
    injection_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id           UUID    NOT NULL,
    round_number     INTEGER NOT NULL,
    catalogue_id     UUID,
    title            TEXT    NOT NULL,
    content          TEXT    NOT NULL,
    tier             TEXT    NOT NULL CHECK (tier IN ('CATALOGUE','ON_THE_FLY')),
    scored           BOOLEAN NOT NULL DEFAULT false,
    canonical_answer TEXT,
    injected_at      TIMESTAMP NOT NULL DEFAULT now(),
    -- The platform must refuse to treat an injected artifact as a graded
    -- round-ender unless a canonical answer exists for it.
    CONSTRAINT ck_injected_scored_needs_answer CHECK (
        scored = false OR canonical_answer IS NOT NULL
    )
);

-- ---------------------------------------------------------------------------
-- 5. Migrate Sim 2 onto the shared clock, then retire its private column so
--    there is a single source of truth for paused time.
-- ---------------------------------------------------------------------------
INSERT INTO run_round_clock (run_id, round_number, paused_seconds_total)
SELECT run_id, round_number, paused_seconds_total
FROM sim2_round_state
ON CONFLICT (run_id, round_number) DO NOTHING;

ALTER TABLE sim2_round_state DROP COLUMN IF EXISTS paused_seconds_total;

COMMIT;
