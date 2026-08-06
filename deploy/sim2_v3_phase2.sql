-- ============================================================================
-- Simulator 2 (Meridian Retail QBR) — v3 migration, PHASE 2: content & answers.
--
-- Run AFTER v3 phase 1. Idempotent.
--   1. answer_type CHECK widened for MULTI.
--   2. Answer key rewritten to v3 (root-cause R2, automate/270 R3, Tableau R4,
--      port R5).
--   3. Board memos rewritten to v3 problem statements + datasets.
--   4. v2-only twists removed (R2 SKU margin, R3 one-screen).
--   5. R3 mid-round artifact: the new month's raw file lands at T+8.
--
-- Sim 2 id: 5116d200-0000-4000-a000-000000000002
-- ============================================================================

BEGIN;

-- ---------------------------------------- 1. answer_type constraint (+MULTI)
ALTER TABLE public.sim2_answer_key DROP CONSTRAINT IF EXISTS sim2_answer_key_answer_type_check;
ALTER TABLE public.sim2_answer_key ADD  CONSTRAINT sim2_answer_key_answer_type_check
  CHECK (answer_type = ANY (ARRAY['NUMERIC'::text,'TEXT'::text,'CHOICE'::text,'FREE_TEXT'::text,'NUMERIC_MULTI'::text,'MULTI'::text]));

-- ---------------------------------------- 2. answer key (v3)
DELETE FROM public.sim2_answer_key WHERE simulation_id = '5116d200-0000-4000-a000-000000000002';
INSERT INTO public.sim2_answer_key
  (simulation_id, round_number, question, canonical_answer, answer_type, tolerance_abs, tolerance_pct, grading_notes)
VALUES
('5116d200-0000-4000-a000-000000000002',1,
 'What is the total revenue for Bluetooth Speaker after parsing, and how many notes classify as Refund Request?',
 '62667;59','MULTI',NULL,NULL,
 'Parse DD-MM-YYYY-ProductName-Price-Quantity via FIND/MID/LEFT/VALUE; classify notes via SEARCH+IFERROR+IF. Bluetooth Speaker revenue = 62,667; Refund Request count = 59. Both required. Dataset: Round1_RawFeed.xlsx.'),
('5116d200-0000-4000-a000-000000000002',2,
 'Is West''s Q1 shortfall a training/execution issue or a market/environment issue, and what is the attainment gap (in percentage points) between West and the rest of the network?',
 'training;25.5','MULTI',NULL,NULL,
 'Training/execution. West avg training 3.5 hrs / attainment 76.0% vs the other four stores 15.75 hrs / 101.5%; correlation(training, attainment) across all 6 stores = 0.99. Gap = 25.5 percentage points. Dataset: Round2_StoreTraining.xlsx.'),
('5116d200-0000-4000-a000-000000000002',3,
 'After combining the new month''s feed with Round 1''s, how many total rows are in the combined dataset?',
 '270','NUMERIC',NULL,NULL,
 '270 = Round1_RawFeed.xlsx (180) + Round3_NewMonth_RawFeed.xlsx (90). Same raw-string format both months.'),
('5116d200-0000-4000-a000-000000000002',4,
 'Which product has the most orders across the combined dataset, and which month had the highest order volume?',
 'Notebook Set;April','MULTI',NULL,NULL,
 'Most orders: Notebook Set (35). Highest-volume month: April (90 orders; Jan 74, Feb 48, Mar 58, Apr 90). Combined 270-row dataset.'),
('5116d200-0000-4000-a000-000000000002',5,
 'Does the Power BI version reproduce Round 4''s most-ordered-product figure exactly? (Yes/No, with the product and count)',
 'Notebook Set;35','MULTI',NULL,NULL,
 'Process-fidelity check. Expected: Yes - Notebook Set, 35 orders. Graded on the product name and count.');

-- ---------------------------------------- 3. remove v2-only twists
DELETE FROM public.artifact_conditions WHERE artifact_id IN
  ('5116d200-0002-4000-a000-000000000023','5116d200-0002-4000-a000-000000000032')
  OR depends_on_decision_id IN ('5116d200-0003-4000-a000-000000000023','5116d200-0003-4000-a000-000000000032');
DELETE FROM public.decision_events   WHERE decision_id IN ('5116d200-0003-4000-a000-000000000023','5116d200-0003-4000-a000-000000000032');
DELETE FROM public.decision_options  WHERE decision_id IN ('5116d200-0003-4000-a000-000000000023','5116d200-0003-4000-a000-000000000032');
DELETE FROM public.decisions         WHERE decision_id IN ('5116d200-0003-4000-a000-000000000023','5116d200-0003-4000-a000-000000000032');
DELETE FROM public.artifacts         WHERE artifact_id IN ('5116d200-0002-4000-a000-000000000023','5116d200-0002-4000-a000-000000000032');

-- ---------------------------------------- 4. board memos (v3)
UPDATE public.artifacts SET open_offset_min = 0, expiry_offset_min = 20,
  payload = '{"tab":"inbox","from":"Head of Strategy","title":"Make sense of this before I trust a single number in it","body":"Our POS system exports transactions as one raw string per row — nobody can read this. Customer service also forwarded complaint notes with no category tag. Parse both before you tell me anything.","files":["Round1_RawFeed.xlsx"],"owner_role":"DATA_QUALITY_ANALYST"}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000001';
UPDATE public.artifacts SET open_offset_min = 0, expiry_offset_min = 20,
  payload = '{"tab":"inbox","from":"Head of Strategy","title":"Why did West miss its target — training, or the market?","body":"West region missed its Q1 revenue target. Is this a training/execution issue with store managers, or something structural the team can''t fix? I need root cause, not just the number. Read the store-level data, apply the 5 Whys / fishbone categories, and quantify the attainment gap between West and the rest of the network.","files":["Round2_StoreTraining.xlsx"],"owner_role":"CATEGORY_REGIONAL_ANALYST"}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000021';
UPDATE public.artifacts SET open_offset_min = 0, expiry_offset_min = 20,
  payload = '{"tab":"inbox","from":"Head of Strategy","title":"This is monthly now — automate it","body":"This report is now a monthly deliverable, and the raw feed lands in the same broken shape every time. Automate it: record a macro for the recurring cleanup, and use Power Query (Get Data > From Folder) to combine the new month''s file with Round 1''s.","owner_role":"REPORTING_DASHBOARD_ANALYST"}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000031';
UPDATE public.artifacts SET open_offset_min = 0, expiry_offset_min = 25,
  payload = '{"tab":"inbox","from":"Head of Strategy","title":"Build the visual story the Board actually reads","body":"Which product is driving order volume, and how is that volume trending month over month? Use the combined Round 1 + Round 3 dataset in Tableau — a most-ordered-product view and a monthly-orders trend. By product, not category: this dataset has no category field, just the discrete products.","owner_role":"PEOPLE_ANALYTICS_ASSOCIATE"}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000041';
UPDATE public.artifacts SET open_offset_min = 0, expiry_offset_min = 20,
  payload = '{"tab":"inbox","from":"Head of Strategy","title":"Port it into Power BI — live, not a static file","body":"Port the model into Power BI so the Board can open and explore it without you in the room. This is a process-fidelity check: reproduce Round 4''s most-ordered-product figure exactly.","owner_role":"AUTOMATION_BI_ASSOCIATE"}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000051';

-- ---------------------------------------- 5. R3 mid-round: new month file lands (T+8)
INSERT INTO public.artifacts
  (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
VALUES
('5116d200-0002-4000-a000-000000000033','5116d200-0001-4000-a000-000000000003','INTERNAL_NOTE',8,20,false,
 '{"tab":"inbox","from":"Data Feed","title":"The new month''s raw file just landed","body":"Same broken format as before. Combine it with Round 1''s feed to build the combined dataset.","files":["Round3_NewMonth_RawFeed.xlsx"]}'::jsonb, NULL)
ON CONFLICT (artifact_id) DO NOTHING;

COMMIT;
