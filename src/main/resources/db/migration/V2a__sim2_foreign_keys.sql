-- ============================================================================
-- Phase 1 (companion) — foreign keys for the sim2_* tables.
--
-- WHY THIS IS SEPARATE:
-- `simulation_runs` is owned by `postgres`, and the application user
-- `simulator_user` has only SELECT/INSERT/UPDATE/DELETE on it — not REFERENCES.
-- Creating an FK requires REFERENCES, so V2 cannot add these. Until this file
-- is applied, run_id integrity for the sim2_* tables is enforced only in the
-- service layer, and deleting a run will NOT cascade-clean its sim2 rows.
--
-- Apply ONCE as a superuser (or as the owner of simulation_runs):
--   psql -h localhost -U postgres -d simulator_db -f V2a__sim2_foreign_keys.sql
--
-- Alternatively, grant the privilege once and V2 becomes self-sufficient:
--   GRANT REFERENCES ON simulation_runs TO simulator_user;
--
-- Idempotent: safe to re-run.
-- ============================================================================

BEGIN;

ALTER TABLE sim2_round_state
    DROP CONSTRAINT IF EXISTS fk_sim2_round_state_run,
    ADD  CONSTRAINT fk_sim2_round_state_run FOREIGN KEY (run_id)
         REFERENCES simulation_runs(run_id) ON DELETE CASCADE;

ALTER TABLE sim2_submissions
    DROP CONSTRAINT IF EXISTS fk_sim2_submission_run,
    ADD  CONSTRAINT fk_sim2_submission_run FOREIGN KEY (run_id)
         REFERENCES simulation_runs(run_id) ON DELETE CASCADE;

ALTER TABLE sim2_construct_scores
    DROP CONSTRAINT IF EXISTS fk_sim2_construct_run,
    ADD  CONSTRAINT fk_sim2_construct_run FOREIGN KEY (run_id)
         REFERENCES simulation_runs(run_id) ON DELETE CASCADE;

COMMIT;
