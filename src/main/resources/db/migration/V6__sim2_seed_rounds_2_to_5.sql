-- ============================================================================
-- Meridian Retail QBR — Rounds 2 to 5
--
-- Content is taken verbatim from the simulation script (DOCX/PDF). Canonical
-- answers come from ANSWER_KEY_FACULTY_ONLY.xlsx and were each re-verified by
-- recomputing from the original Meridian_Retail_Master_Dataset.xlsx:
--
--   R2  Electronics Accessories deduction-adjusted margin = 53.43 -> 53.4
--       (shortcut method, ignoring the deduction, gives 54.9)
--   R3  Growth by channel: India Stores = 230,739 exactly
--   R4  Below-median revenue AND above-median attrition = STR04
--   R5  Process-fidelity check against the Round 3 figure = 230,739
--
-- Round 6 is deliberately NOT seeded here: its closing question is free text
-- with no canonical answer, so how it should be scored is still an open
-- product decision.
--
-- Idempotent: safe to re-run.
-- ============================================================================

BEGIN;

-- Fixed ids: 5116d200-0001-... rounds, -0002-... artifacts, -0003-... decisions
-- Round N uses ...-000N in the last group.

-- ---------------------------------------------------------------------------
-- Rounds (durations from the script: 18 / 24 / 24 / 20)
-- ---------------------------------------------------------------------------
INSERT INTO rounds (round_id, simulation_id, round_number, duration_minutes) VALUES
 ('5116d200-0001-4000-a000-000000000002','5116d200-0000-4000-a000-000000000002',2,18),
 ('5116d200-0001-4000-a000-000000000003','5116d200-0000-4000-a000-000000000002',3,24),
 ('5116d200-0001-4000-a000-000000000004','5116d200-0000-4000-a000-000000000002',4,24),
 ('5116d200-0001-4000-a000-000000000005','5116d200-0000-4000-a000-000000000002',5,20)
ON CONFLICT (simulation_id, round_number) DO UPDATE SET duration_minutes = EXCLUDED.duration_minutes;

DELETE FROM artifacts WHERE round_id IN (
  '5116d200-0001-4000-a000-000000000002','5116d200-0001-4000-a000-000000000003',
  '5116d200-0001-4000-a000-000000000004','5116d200-0001-4000-a000-000000000005');

-- ===========================================================================
-- ROUND 2 — "Which regions and categories are actually driving growth?"
-- 18 min | Owner: Category & Regional Analyst
-- ===========================================================================
INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min,
                       expected_action, payload, allowed_roles)
VALUES (
 '5116d200-0002-4000-a000-000000000021','5116d200-0001-4000-a000-000000000002',
 'BOARD_MEMO', 0, 18, false,
 jsonb_build_object('tab','inbox','from','Head of Strategy',
   'title','Which regions and categories are actually driving growth?',
   'body','Are specific categories and regions genuinely growing, or just moving more volume at lower margin?',
   'owner_role','CATEGORY_REGIONAL_ANALYST'),
 NULL);

-- R1 -> R2 conditional: only appears if the team resolved the Round 1 twist by
-- DELETING rows, in which case their row count no longer ties to the original file.
INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min,
                       expected_action, payload, allowed_roles)
VALUES (
 '5116d200-0002-4000-a000-000000000022','5116d200-0001-4000-a000-000000000002',
 'RECONCILIATION_FLAG', 0, 18, false,
 jsonb_build_object('tab','inbox','from','Finance Operations',
   'title','Reconciliation flag',
   'body','Row count no longer matches the file originally submitted: rows were deleted rather than excluded, so the totals cannot be traced back to the source extract.'),
 NULL);

INSERT INTO artifact_conditions (artifact_id, depends_on_decision_id, expected_action)
VALUES ('5116d200-0002-4000-a000-000000000022','5116d200-0003-4000-a000-000000000002','DELETE_ROWS');

-- Twist. NOTE: the script wording alone does not state that the deduction applies
-- only to online-channel sales, but the answer key depends on exactly that. The
-- precise rule is spelled out here so the question is answerable as authored.
INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min,
                       expected_action, payload, allowed_roles)
VALUES (
 '5116d200-0002-4000-a000-000000000023','5116d200-0001-4000-a000-000000000002',
 'TWIST', 9, 18, true,
 jsonb_build_object('tab','decisions','from','Commercial Finance',
   'title','Two margin figures for the same SKU',
   'body','The product master has 2 SKUs (AP-104 and EA-501) with two margin figures each: a list price, and one reflecting a channel-specific deduction agreement. The deduction applies only to that SKU sold through the online channel; the same SKU sold in-store still uses list price. Reprice accordingly before computing category margins.',
   'owner_role','CATEGORY_REGIONAL_ANALYST'),
 NULL);

INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, options, allowed_roles)
VALUES ('5116d200-0003-4000-a000-000000000023','5116d200-0002-4000-a000-000000000023','EXPLICIT',false,
 jsonb_build_array(
   jsonb_build_object('id','DEDUCTION_AUTHORITATIVE','label','Treat the deduction-adjusted figure as authoritative and justify in one line'),
   jsonb_build_object('id','LIST_PRICE_AUTHORITATIVE','label','Treat list price as authoritative and justify'),
   jsonb_build_object('id','FLAG_BOTH_UNRESOLVED','label','Flag both, unresolved')),
 jsonb_build_array('CATEGORY_REGIONAL_ANALYST','TEAM_LEAD'));

INSERT INTO decision_options (decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta) VALUES
 ('5116d200-0003-4000-a000-000000000023','DEDUCTION_AUTHORITATIVE',0,0,0,0),
 ('5116d200-0003-4000-a000-000000000023','LIST_PRICE_AUTHORITATIVE',0,0,0,0),
 ('5116d200-0003-4000-a000-000000000023','FLAG_BOTH_UNRESOLVED',0,0,0,0);

-- ===========================================================================
-- ROUND 3 — "Give me a one-page summary the Board can filter themselves"
-- 24 min | Owner: Reporting & Dashboard Analyst
-- ===========================================================================
INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min,
                       expected_action, payload, allowed_roles)
VALUES (
 '5116d200-0002-4000-a000-000000000031','5116d200-0001-4000-a000-000000000003',
 'BOARD_MEMO', 0, 24, false,
 jsonb_build_object('tab','inbox','from','Head of Strategy',
   'title','Give me a one-page summary the Board can filter themselves',
   'body','Convert this into a one-page, interactive summary covering region, category and channel. The Board wants to filter it live, not call the team back. Prior-quarter reference data is attached for the growth comparison.',
   'files', jsonb_build_array('Round3_PriorQuarter_Q4FY25_Clean.xlsx'),
   'owner_role','REPORTING_DASHBOARD_ANALYST'),
 NULL);

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min,
                       expected_action, payload, allowed_roles)
VALUES (
 '5116d200-0002-4000-a000-000000000032','5116d200-0001-4000-a000-000000000003',
 'TWIST', 14, 24, true,
 jsonb_build_object('tab','decisions','from','Head of Strategy',
   'title','Keep it to one screen',
   'body','Keep it to one screen. The Board does not scroll.',
   'owner_role','REPORTING_DASHBOARD_ANALYST'),
 NULL);

INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, options, allowed_roles)
VALUES ('5116d200-0003-4000-a000-000000000032','5116d200-0002-4000-a000-000000000032','EXPLICIT',false,
 jsonb_build_array(
   jsonb_build_object('id','CUT_TO_ESSENTIAL','label','Cut to essential fields'),
   jsonb_build_object('id','SHRINK_TO_FIT','label','Shrink everything to fit'),
   jsonb_build_object('id','SPLIT_TWO_SCREENS','label','Split across two screens anyway')),
 jsonb_build_array('REPORTING_DASHBOARD_ANALYST','TEAM_LEAD'));

INSERT INTO decision_options (decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta) VALUES
 ('5116d200-0003-4000-a000-000000000032','CUT_TO_ESSENTIAL',0,0,0,0),
 ('5116d200-0003-4000-a000-000000000032','SHRINK_TO_FIT',0,0,0,0),
 ('5116d200-0003-4000-a000-000000000032','SPLIT_TWO_SCREENS',0,0,0,0);

-- ===========================================================================
-- ROUND 4 — "Is store performance related to staffing stability?"
-- 24 min | Owner: People Analytics Associate
-- ===========================================================================
INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min,
                       expected_action, payload, allowed_roles)
VALUES (
 '5116d200-0002-4000-a000-000000000041','5116d200-0001-4000-a000-000000000004',
 'BOARD_MEMO', 0, 24, false,
 jsonb_build_object('tab','inbox','from','Head of Strategy',
   'title','Is store performance related to staffing stability?',
   'body','HR has sent store-level headcount and attrition. Is underperformance linked to how fast a store is losing staff?',
   'files', jsonb_build_array('Round4_HR_Headcount_Attrition.xlsx'),
   'owner_role','PEOPLE_ANALYTICS_ASSOCIATE'),
 NULL);

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min,
                       expected_action, payload, allowed_roles)
VALUES (
 '5116d200-0002-4000-a000-000000000042','5116d200-0001-4000-a000-000000000004',
 'TWIST', 12, 24, true,
 jsonb_build_object('tab','decisions','from','People Analytics',
   'title','The join will not build',
   'body','The HR file uses store names; every other table uses Store ID. The relationship will not build until this is reconciled.',
   'owner_role','PEOPLE_ANALYTICS_ASSOCIATE'),
 NULL);

INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, options, allowed_roles)
VALUES ('5116d200-0003-4000-a000-000000000042','5116d200-0002-4000-a000-000000000042','EXPLICIT',false,
 jsonb_build_array(
   jsonb_build_object('id','REPEATABLE_MERGE','label','Build a repeatable lookup or merge'),
   jsonb_build_object('id','MANUAL_RETYPING','label','Re-type the keys manually'),
   jsonb_build_object('id','DROP_UNMATCHED','label','Drop the unmatched stores')),
 jsonb_build_array('PEOPLE_ANALYTICS_ASSOCIATE','TEAM_LEAD'));

INSERT INTO decision_options (decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta) VALUES
 ('5116d200-0003-4000-a000-000000000042','REPEATABLE_MERGE',0,0,0,0),
 ('5116d200-0003-4000-a000-000000000042','MANUAL_RETYPING',0,0,0,0),
 ('5116d200-0003-4000-a000-000000000042','DROP_UNMATCHED',0,0,0,0);

-- ===========================================================================
-- ROUND 5 — "Board wants this live, not a static file"
-- 20 min | Owner: Automation & BI Associate | No twist
-- ===========================================================================
INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min,
                       expected_action, payload, allowed_roles)
VALUES (
 '5116d200-0002-4000-a000-000000000051','5116d200-0001-4000-a000-000000000005',
 'BOARD_MEMO', 0, 20, false,
 jsonb_build_object('tab','inbox','from','Head of Strategy',
   'title','Board wants this live, not a static file',
   'body','Port the model into Power BI. The Board should be able to open and explore it without you in the room.',
   'owner_role','AUTOMATION_BI_ASSOCIATE'),
 NULL);

-- R4 -> R5 conditional: only if the join twist was resolved by dropping stores.
INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min,
                       expected_action, payload, allowed_roles)
VALUES (
 '5116d200-0002-4000-a000-000000000052','5116d200-0001-4000-a000-000000000005',
 'COVERAGE_GAP_NOTE', 0, 20, false,
 jsonb_build_object('tab','inbox','from','People Analytics',
   'title','Coverage gap',
   'body','Unmatched stores were dropped rather than reconciled, so the model no longer covers the full store network.'),
 NULL);

INSERT INTO artifact_conditions (artifact_id, depends_on_decision_id, expected_action)
VALUES ('5116d200-0002-4000-a000-000000000052','5116d200-0003-4000-a000-000000000042','DROP_UNMATCHED');

-- ===========================================================================
-- Answer keys
-- ===========================================================================
INSERT INTO sim2_answer_key (simulation_id, round_number, question, canonical_answer,
                             answer_type, tolerance_abs, tolerance_pct, grading_notes) VALUES
 ('5116d200-0000-4000-a000-000000000002', 2,
  'What is this quarter''s deduction-adjusted margin % for the Electronics Accessories category? (nearest 0.1%)',
  '53.4','NUMERIC',1.0,NULL,
  'Verified by recomputation: applying the deduction to online-channel sales of AP-104 and EA-501 only gives 53.43 for Electronics Accessories. The shortcut of using list price throughout gives 54.9, so the question is diagnostic of whether the twist was actually resolved. The plus or minus 1.0 point band is 52.4 to 54.4 and excludes 54.9 by only 0.5 - do not widen it.'),

 ('5116d200-0000-4000-a000-000000000002', 3,
  'Which channel (India stores / India online / international online) contributed the most to this quarter''s growth?',
  'India Stores','TEXT',NULL,NULL,
  'Verified by recomputation against the prior-quarter file: India Stores growth = 230,739 exactly, well ahead of the other two channels on any pricing basis.'),

 ('5116d200-0000-4000-a000-000000000002', 4,
  'Which store has both below-median revenue and above-median attrition?',
  'STR04','TEXT',NULL,NULL,
  'Verified by recomputation across the 4 India stores: below-median revenue = STR04 and STR02; above-median attrition = STR01 and STR04; the intersection is STR04 (Pune, Camp Area). Not a close call.'),

 ('5116d200-0000-4000-a000-000000000002', 5,
  'Does the ported dashboard reproduce the Round 3 growth-by-channel figure exactly? (Yes/No, with the figure)',
  '230739','NUMERIC',0,NULL,
  'Process-fidelity check, not a new computation: the expected figure is the Round 3 India Stores growth of 230,739. Graded on the figure, which is extracted from the sentence, so "Yes - India Stores: 230,739 INR" is accepted.')
ON CONFLICT (simulation_id, round_number) DO UPDATE
  SET question = EXCLUDED.question, canonical_answer = EXCLUDED.canonical_answer,
      answer_type = EXCLUDED.answer_type, tolerance_abs = EXCLUDED.tolerance_abs,
      tolerance_pct = EXCLUDED.tolerance_pct, grading_notes = EXCLUDED.grading_notes;

COMMIT;
