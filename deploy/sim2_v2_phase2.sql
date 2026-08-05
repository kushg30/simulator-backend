-- ============================================================================
-- Simulator 2 (Meridian Retail QBR) — v2 migration, PHASE 2: content & answers.
--
-- Run AFTER sim2_v2_setup.sql (Phase 1). Idempotent.
--   1. Answer key rewritten to v2 (R1 two figures, R2 category name, new R3/R4/R5).
--   2. answer_type CHECK widened for NUMERIC_MULTI.
--   3. Board memos + twists rewritten to v2 text/offsets.
--   4. Dropped artifacts removed (R1 voided-txn twist, R2 reconciliation flag,
--      R4 HR-join twist, R5 coverage-gap note) — v2 does not use them.
--
-- Sim 2 id: 5116d200-0000-4000-a000-000000000002
-- ============================================================================

BEGIN;

-- ---------------------------------------- 1. answer_type constraint (+NUMERIC_MULTI)
ALTER TABLE public.sim2_answer_key DROP CONSTRAINT IF EXISTS sim2_answer_key_answer_type_check;
ALTER TABLE public.sim2_answer_key ADD  CONSTRAINT sim2_answer_key_answer_type_check
  CHECK (answer_type = ANY (ARRAY['NUMERIC'::text,'TEXT'::text,'CHOICE'::text,'FREE_TEXT'::text,'NUMERIC_MULTI'::text]));

-- ---------------------------------------- 2. answer key (v2)
DELETE FROM public.sim2_answer_key WHERE simulation_id = '5116d200-0000-4000-a000-000000000002';
INSERT INTO public.sim2_answer_key
  (simulation_id, round_number, question, canonical_answer, answer_type, tolerance_abs, tolerance_pct, grading_notes)
VALUES
('5116d200-0000-4000-a000-000000000002',1,
 'What is the total revenue (Price x Quantity) for Bluetooth Speaker after parsing, and how many notes classify as Refund Request?',
 '62667;59','NUMERIC_MULTI',NULL,NULL,
 'Parse the raw string DD-MM-YYYY-ProductName-Price-Quantity via FIND/MID/LEFT/VALUE; classify notes via SEARCH+IFERROR+IF. Bluetooth Speaker revenue = 62,667; Refund Request count = 59. Both figures must be present. Dataset: Round1_RawFeed.xlsx (180 rows).'),
('5116d200-0000-4000-a000-000000000002',2,
 'Which category has the highest deduction-adjusted margin this quarter?',
 'Beauty & Personal Care','TEXT',NULL,NULL,
 'Highest deduction-adjusted margin = Beauty & Personal Care at 56.99%. The deduction applies to online-channel sales of AP-104 and EA-501 only; store-channel sales of the same SKUs use list price.'),
('5116d200-0000-4000-a000-000000000002',3,
 'Which channel (India Stores / India Online / International Online) contributed the most to this quarter''s growth?',
 'India Stores','TEXT',NULL,NULL,
 'Growth by channel (INR): India Online 110,326; India Stores 237,091; International Online 229,981. India Stores is the largest.'),
('5116d200-0000-4000-a000-000000000002',4,
 'After filtering to West region + Online channel only, what is the total revenue?',
 '344382','NUMERIC',NULL,NULL,
 '344,382 INR across 109 transactions. West = STR03, STR04. Exact figure.'),
('5116d200-0000-4000-a000-000000000002',5,
 'Does the ported dashboard reproduce the Round 4 filtered figure exactly? (Yes/No, with the figure)',
 '344382','NUMERIC',NULL,NULL,
 'Process-fidelity check, not a new computation. Expected: Yes - 344,382 INR. Graded on the figure extracted from the sentence.');

-- ---------------------------------------- 3. remove dropped artifacts
-- R1 voided-txn twist (..0002 + decision ..0002), R2 reconciliation flag (..0022),
-- R4 HR-join twist (..0042 + decision ..0042), R5 coverage-gap note (..0052).
DELETE FROM public.artifact_conditions WHERE artifact_id IN (
  '5116d200-0002-4000-a000-000000000002','5116d200-0002-4000-a000-000000000022',
  '5116d200-0002-4000-a000-000000000042','5116d200-0002-4000-a000-000000000052');
DELETE FROM public.decision_events WHERE decision_id IN (
  '5116d200-0003-4000-a000-000000000002','5116d200-0003-4000-a000-000000000042');
DELETE FROM public.decision_options WHERE decision_id IN (
  '5116d200-0003-4000-a000-000000000002','5116d200-0003-4000-a000-000000000042');
DELETE FROM public.decisions WHERE decision_id IN (
  '5116d200-0003-4000-a000-000000000002','5116d200-0003-4000-a000-000000000042');
DELETE FROM public.artifacts WHERE artifact_id IN (
  '5116d200-0002-4000-a000-000000000002','5116d200-0002-4000-a000-000000000022',
  '5116d200-0002-4000-a000-000000000042','5116d200-0002-4000-a000-000000000052');

-- ---------------------------------------- 4. board memos (v2 text + offsets)
-- R1
UPDATE public.artifacts SET open_offset_min = 0, expiry_offset_min = 20,
  payload = '{"tab":"inbox","from":"Head of Strategy","title":"Make sense of this before I trust a single number in it","body":"Our POS system exports transactions as one raw string per row — I can''t read this. Customer service also forwarded complaint notes with no category tag. I need both fixed before I can tell the Board anything.","files":["Round1_RawFeed.xlsx"],"owner_role":"DATA_QUALITY_ANALYST"}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000001';
-- R2
UPDATE public.artifacts SET open_offset_min = 0, expiry_offset_min = 20,
  payload = '{"tab":"inbox","from":"Head of Strategy","title":"Which categories are genuinely more profitable, not just bigger?","body":"Are specific categories and regions genuinely growing, or just moving more volume at lower margin?","owner_role":"CATEGORY_REGIONAL_ANALYST"}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000021';
-- R2 twist (SKU margin) — text + offsets
UPDATE public.artifacts SET open_offset_min = 9, expiry_offset_min = 20,
  payload = '{"tab":"decisions","from":"Commercial Finance","title":"Two margin figures for the same SKU","body":"The product master has 2 SKUs (AP-104 and EA-501) with two margin figures each — a list price and a channel-specific deduction agreement. The deduction applies only to that SKU''s online-channel sales; the same SKU sold in-store still uses list price. Decide how to apply it before computing category margins.","owner_role":"CATEGORY_REGIONAL_ANALYST"}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000023';
-- R3
UPDATE public.artifacts SET open_offset_min = 0, expiry_offset_min = 25,
  payload = '{"tab":"inbox","from":"Head of Strategy","title":"Give me a one-page summary the Board can act on","body":"Convert this into a one-page PivotTable/Chart summary — region, category and channel, versus last quarter. The Board wants to read one screen, not scroll a workbook. Prior-quarter reference data is attached for the growth comparison.","files":["Round3_PriorQuarter_Q4FY25_Clean.xlsx"],"owner_role":"REPORTING_DASHBOARD_ANALYST"}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000031';
-- R3 twist (one screen) — offsets
UPDATE public.artifacts SET open_offset_min = 14, expiry_offset_min = 25,
  payload = '{"tab":"decisions","from":"Head of Strategy","title":"Keep it to one screen","body":"Keep it to one screen — the Board doesn''t scroll.","owner_role":"REPORTING_DASHBOARD_ANALYST"}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000032';
-- R4 (fully replaced: slicers + timeline)
UPDATE public.artifacts SET open_offset_min = 0, expiry_offset_min = 20,
  payload = '{"tab":"inbox","from":"Head of Strategy","title":"The Board wants to filter this themselves","body":"Add slicers (region, category, channel) and a timeline to Round 3''s pivot. The Board wants to filter live in the meeting, not call the team back.","owner_role":"PEOPLE_ANALYTICS_ASSOCIATE"}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000041';
-- R5
UPDATE public.artifacts SET open_offset_min = 0, expiry_offset_min = 20,
  payload = '{"tab":"inbox","from":"Head of Strategy","title":"Board wants this live, not a static file","body":"Port the model into Power BI or Tableau — whichever the team is more comfortable with. The Board should be able to open and explore it without you in the room.","owner_role":"AUTOMATION_BI_ASSOCIATE"}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000051';

-- ---------------------------------------- 5. R2 twist decision options (v2)
UPDATE public.decisions SET options =
  '[{"id":"APPLY_CHANNEL_CONDITIONAL","label":"Apply the channel-conditional rule"},{"id":"APPLY_TO_ALL_SALES","label":"Apply the deduction to all sales of the SKU regardless of channel"},{"id":"FLAG_BOTH_UNRESOLVED","label":"Flag both, unresolved"}]'::jsonb
 WHERE decision_id = '5116d200-0003-4000-a000-000000000023';
DELETE FROM public.decision_options WHERE decision_id = '5116d200-0003-4000-a000-000000000023';
INSERT INTO public.decision_options (decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta) VALUES
('5116d200-0003-4000-a000-000000000023','APPLY_CHANNEL_CONDITIONAL',0,0,0,0),
('5116d200-0003-4000-a000-000000000023','APPLY_TO_ALL_SALES',0,0,0,0),
('5116d200-0003-4000-a000-000000000023','FLAG_BOTH_UNRESOLVED',0,0,0,0);

COMMIT;
