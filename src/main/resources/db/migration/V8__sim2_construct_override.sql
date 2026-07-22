-- ============================================================================
-- Faculty override of finalised construct scores.
--
-- Data Trust Score and Insight Communication are derived from structured proxies
-- (recorded decisions and answer-checks), not from reading the actual workbook or
-- prose. A facilitator with the submission in front of them may disagree, so they
-- can override any finalised construct. The auto-computed value is preserved so
-- the override is reversible, and every override is written to faculty_actions.
--
-- Idempotent: safe to re-run.
-- ============================================================================

BEGIN;

-- Override provenance on the run-level (round 0) construct rows.
ALTER TABLE sim2_construct_scores ADD COLUMN IF NOT EXISTS original_value  INTEGER;
ALTER TABLE sim2_construct_scores ADD COLUMN IF NOT EXISTS overridden_by   TEXT;
ALTER TABLE sim2_construct_scores ADD COLUMN IF NOT EXISTS override_reason TEXT;
ALTER TABLE sim2_construct_scores ADD COLUMN IF NOT EXISTS overridden_at   TIMESTAMP;

-- Allow the override action in the shared facilitator action log.
ALTER TABLE faculty_actions DROP CONSTRAINT IF EXISTS faculty_actions_action_type_check;
ALTER TABLE faculty_actions ADD  CONSTRAINT faculty_actions_action_type_check
    CHECK (action_type IN ('PAUSE','RESUME','DELAY','BYPASS','INJECT','OVERRIDE'));

COMMIT;
