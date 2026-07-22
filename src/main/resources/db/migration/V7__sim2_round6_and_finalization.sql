-- ============================================================================
-- Meridian Retail QBR — Round 6, plus support for end-of-engagement scoring.
--
-- Round 6 is the consolidation round. Its closing question is free text with no
-- canonical answer ("Across all six rounds, where was your team's biggest risk
-- to data reliability?"), so it cannot be auto-graded. Instead:
--
--   * Round 6 scores Turnaround Discipline only (time based). Analytical Rigor
--     and Judgment Calibration are NOT_APPLICABLE for the round - there is no
--     answer to check, and a zero would misrepresent that.
--   * Round 6 is the trigger for finalising the two run-level constructs that
--     were deferred through Rounds 1-5: Data Trust Score and Insight
--     Communication. Those are computed from signals already captured across the
--     whole run and stored as round_number = 0 (the run-level final reveal).
--
-- Idempotent: safe to re-run.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Allow the new construct status and free-text answer type.
-- ---------------------------------------------------------------------------
ALTER TABLE sim2_construct_scores DROP CONSTRAINT IF EXISTS sim2_construct_scores_status_check;
ALTER TABLE sim2_construct_scores ADD  CONSTRAINT sim2_construct_scores_status_check
    CHECK (status IN ('SCORED','NOT_YET_SCORED','NOT_APPLICABLE'));

-- NOT_APPLICABLE, like NOT_YET_SCORED, has a null value.
ALTER TABLE sim2_construct_scores DROP CONSTRAINT IF EXISTS ck_sim2_value_present;
ALTER TABLE sim2_construct_scores ADD  CONSTRAINT ck_sim2_value_present CHECK (
    (status = 'SCORED' AND value IS NOT NULL) OR
    (status IN ('NOT_YET_SCORED','NOT_APPLICABLE') AND value IS NULL)
);

ALTER TABLE sim2_answer_key DROP CONSTRAINT IF EXISTS sim2_answer_key_answer_type_check;
ALTER TABLE sim2_answer_key ADD  CONSTRAINT sim2_answer_key_answer_type_check
    CHECK (answer_type IN ('NUMERIC','TEXT','CHOICE','FREE_TEXT'));

-- ---------------------------------------------------------------------------
-- 2. Round 6 — "This goes out monthly — automate what you can" (16 min, no twist)
-- ---------------------------------------------------------------------------
INSERT INTO rounds (round_id, simulation_id, round_number, duration_minutes)
VALUES ('5116d200-0001-4000-a000-000000000006','5116d200-0000-4000-a000-000000000002',6,16)
ON CONFLICT (simulation_id, round_number) DO UPDATE SET duration_minutes = EXCLUDED.duration_minutes;

DELETE FROM artifacts WHERE round_id = '5116d200-0001-4000-a000-000000000006';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min,
                       expected_action, payload, allowed_roles)
VALUES (
 '5116d200-0002-4000-a000-000000000061','5116d200-0001-4000-a000-000000000006',
 'BOARD_MEMO', 0, 16, false,
 jsonb_build_object('tab','inbox','from','Head of Strategy',
   'title','This goes out monthly — automate what you can',
   'body','This is now a monthly deliverable. Automate the refresh and export. For your closing submission, reflect across all six rounds: where was your team''s biggest risk to data reliability?',
   'owner_role','AUTOMATION_BI_ASSOCIATE'),
 NULL);

-- ---------------------------------------------------------------------------
-- 3. Round 6 question (free text, ungraded). Stored so the UI can show the
--    prompt; grading treats FREE_TEXT as ungraded and records no correctness.
-- ---------------------------------------------------------------------------
INSERT INTO sim2_answer_key (simulation_id, round_number, question, canonical_answer,
                             answer_type, tolerance_abs, tolerance_pct, grading_notes)
VALUES (
 '5116d200-0000-4000-a000-000000000002', 6,
 'Across all six rounds, where was your team''s biggest risk to data reliability? (one line)',
 'N/A','FREE_TEXT',NULL,NULL,
 'Free-text reflection, no canonical answer. Used for the debrief and, together with the confidence '
 || 'tag, as colour on Insight Communication. Round 6 itself scores only Turnaround Discipline.')
ON CONFLICT (simulation_id, round_number) DO UPDATE
  SET question = EXCLUDED.question, canonical_answer = EXCLUDED.canonical_answer,
      answer_type = EXCLUDED.answer_type, grading_notes = EXCLUDED.grading_notes;

COMMIT;
