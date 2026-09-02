-- Cross-participant conditional support for Sim 1 (script fidelity):
--   * artifact_conditions.cross_role — when true, the condition matches ANY participant's decision
--     (e.g. the CEO's R1 framing gating a CEO-authored artifact seen by a different role). Default
--     false preserves the existing same-participant behaviour (Diagnostic Summary).
--   * expected_action may now be a comma-list = OR of acceptable trigger actions (handled in the
--     visibility query via string_to_array).
BEGIN;
ALTER TABLE artifact_conditions ADD COLUMN IF NOT EXISTS cross_role boolean NOT NULL DEFAULT false;
COMMIT;
