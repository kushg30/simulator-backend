-- ============================================================================
-- Phase 1 — Simulator 2 (Meridian Retail QBR) engine tables
--
-- Sim 2 is a separate engine from Sim 1, not a variant:
--   * 6 sequential rounds, each with its own clock (Sim 1 = one run-long clock)
--   * submissions are a file + a typed answer + a confidence tag
--   * answers are auto-graded against a faculty-only answer key
--   * constructs are performance measures, and students DO see numeric scores
--
-- All tables are prefixed `sim2_` so nothing here can affect Simulation 1.
-- Idempotent: safe to re-run.
--
-- NOTE ON FOREIGN KEYS: `simulation_runs` is owned by `postgres` and
-- `simulator_user` has DML but not REFERENCES on it, so the FKs to run_id
-- cannot be created by the application user. They live in the companion file
-- V2a__sim2_foreign_keys.sql, to be applied once as a superuser. Until then
-- referential integrity for run_id is enforced in the service layer.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Per-run, per-round lifecycle.
-- Artifact offsets in Sim 2 are relative to ROUND start (Sim 1 uses run start)
-- which is exactly why Sim 2 needs its own read path.
--
-- `paused_seconds_total` is populated by the Phase-2 faculty control layer and
-- defaults to 0, so Turnaround Discipline can be computed correctly today and
-- keeps working unchanged once pausing exists.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sim2_round_state (
    run_id               UUID    NOT NULL,
    round_number         INTEGER NOT NULL,
    status               TEXT    NOT NULL DEFAULT 'PENDING'
                                 CHECK (status IN ('PENDING','ACTIVE','COMPLETE','BYPASSED')),
    started_at           TIMESTAMP,
    ends_at              TIMESTAMP,
    paused_seconds_total INTEGER NOT NULL DEFAULT 0 CHECK (paused_seconds_total >= 0),
    completed_at         TIMESTAMP,
    CONSTRAINT pk_sim2_round_state PRIMARY KEY (run_id, round_number)
);

-- ---------------------------------------------------------------------------
-- Faculty-only canonical answers. MUST NEVER be exposed on a student endpoint.
--
-- answer_type NUMERIC  -> compare numerically within tolerance_abs / tolerance_pct
-- answer_type TEXT     -> normalized case-insensitive compare
-- answer_type CHOICE   -> exact match against a fixed option
-- Both tolerances NULL  -> exact match required (Round 1).
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sim2_answer_key (
    simulation_id    UUID    NOT NULL,
    round_number     INTEGER NOT NULL,
    question         TEXT    NOT NULL,
    canonical_answer TEXT    NOT NULL,
    answer_type      TEXT    NOT NULL CHECK (answer_type IN ('NUMERIC','TEXT','CHOICE')),
    tolerance_abs    NUMERIC,
    tolerance_pct    NUMERIC,
    grading_notes    TEXT,
    CONSTRAINT pk_sim2_answer_key PRIMARY KEY (simulation_id, round_number)
);

-- ---------------------------------------------------------------------------
-- One submission per team per round: the workbook plus the graded answer.
-- The file is stored for faculty review only and is never machine-parsed —
-- the spec grades technique "via the answer-check, not formula inspection".
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sim2_submissions (
    submission_id       UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id              UUID    NOT NULL,
    round_number        INTEGER NOT NULL,
    submitted_by        UUID    NOT NULL,
    file_path           TEXT,
    original_filename   TEXT,
    typed_answer        TEXT    NOT NULL,
    confidence          TEXT    NOT NULL CHECK (confidence IN ('HIGH','MEDIUM','LOW')),
    submitted_at        TIMESTAMP NOT NULL DEFAULT now(),
    active_seconds_used INTEGER,
    is_correct          BOOLEAN,
    score_detail        JSONB,
    CONSTRAINT uq_sim2_submission_round UNIQUE (run_id, round_number)
);

-- ---------------------------------------------------------------------------
-- Per-round construct scores.
--
-- `value` is NULL when status = 'NOT_YET_SCORED'. This is deliberate: Data Trust
-- Score tracks whether numbers survive LATER rounds, and Insight Communication
-- has no signal until R3/R6 — recording either as 0 in Round 1 would silently
-- understate every team. A bypassed round is likewise excluded from the rollup,
-- never scored as zero.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sim2_construct_scores (
    run_id         UUID    NOT NULL,
    round_number   INTEGER NOT NULL,
    construct_name TEXT    NOT NULL CHECK (construct_name IN (
                       'DATA_TRUST_SCORE','ANALYTICAL_RIGOR','INSIGHT_COMMUNICATION',
                       'JUDGMENT_CALIBRATION','TURNAROUND_DISCIPLINE')),
    value          INTEGER CHECK (value BETWEEN 0 AND 100),
    status         TEXT    NOT NULL DEFAULT 'SCORED'
                           CHECK (status IN ('SCORED','NOT_YET_SCORED')),
    detail         TEXT,
    calculated_at  TIMESTAMP NOT NULL DEFAULT now(),
    CONSTRAINT pk_sim2_construct_scores PRIMARY KEY (run_id, round_number, construct_name),
    CONSTRAINT ck_sim2_value_present CHECK (
        (status = 'SCORED' AND value IS NOT NULL) OR
        (status = 'NOT_YET_SCORED' AND value IS NULL)
    )
);

COMMIT;
