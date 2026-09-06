-- Reliability + features for Sim 1.
--  (a) Indexes on the hot paths (visibility + silence run on every 3s poll per client). Under a full
--      cohort the default plans were doing repeated scans; these make each poll cheap so the small
--      connection pool is not held long enough to exhaust under load ("failed to fetch").
--  (b) sim1_round_state.interstitial_acked — the CEO acknowledges the post-round debrief so the team
--      advances together on the CEO's click instead of an auto-timer.
BEGIN;

CREATE INDEX IF NOT EXISTS idx_decision_events_run_dec   ON decision_events(run_id, decision_id);
CREATE INDEX IF NOT EXISTS idx_artifacts_round           ON artifacts(round_id);
CREATE INDEX IF NOT EXISTS idx_decisions_artifact        ON decisions(artifact_id);
CREATE INDEX IF NOT EXISTS idx_decision_options_decision ON decision_options(decision_id);
CREATE INDEX IF NOT EXISTS idx_artifact_conditions_art   ON artifact_conditions(artifact_id);
CREATE INDEX IF NOT EXISTS idx_sim1_option_constructs_opt ON sim1_option_constructs(option_id);

ALTER TABLE sim1_round_state ADD COLUMN IF NOT EXISTS interstitial_acked boolean NOT NULL DEFAULT false;

COMMIT;
