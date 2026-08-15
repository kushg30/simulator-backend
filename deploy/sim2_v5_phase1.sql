-- ═══════════════════════════════════════════════════════════════════════════
-- Sim 2 (Meridian QBR) v5 — answer keys + question text.
-- Source of truth: ~/Downloads/sim2_v5/ANSWER_KEY_FACULTY_ONLY.xlsx
-- (canonical numbers independently recomputed from the raw feeds and confirmed).
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE sim uuid := '5116d200-0000-4000-a000-000000000002';
BEGIN

-- Round 1 — refund-count question REMOVED; only Bluetooth Speaker revenue is graded.
-- RawString is now SerialDate-Product-Price-Qty (serial dates). Tags unchanged.
UPDATE sim2_answer_key
   SET canonical_answer = '62667',
       question = 'What is the total revenue (Price x Quantity) for Bluetooth Speaker after analysing the raw feed? Then flag what is wrong with the feed.'
 WHERE simulation_id = sim AND round_number = 1;

-- Round 2 — root cause reframed from a binary into four fishbone categories.
-- Correct = People (Training & Skill Gap); gap still 25.5pp.
UPDATE sim2_answer_key
   SET canonical_answer = 'People;25.5',
       question = 'Which root cause best explains the West region shortfall - People, Process, Market or Resource - and what is the attainment gap vs the rest of the network (percentage points)?'
 WHERE simulation_id = sim AND round_number = 2;

-- Round 3 — adds the anti-shortcut total combined revenue (1,381,546); file upload
-- dropped in favour of a macro Yes/No + keyword-checked description.
UPDATE sim2_answer_key
   SET answer_type = 'MULTI',
       canonical_answer = '270;1381546',
       question = 'After combining Round 1 and the new month feed via a recorded macro: what is the total combined row count, and the total revenue (Price x Quantity) across the full combined dataset?'
 WHERE simulation_id = sim AND round_number = 3;

-- Round 4 — values unchanged; now tool-agnostic (Tableau or Power BI), chart type
-- self-declared, file upload dropped.
UPDATE sim2_answer_key
   SET canonical_answer = 'Notebook Set;35;April;90',
       question = 'Which product has the most orders across the combined dataset, and which month had the highest order volume? Use Tableau or Power BI - your choice.'
 WHERE simulation_id = sim AND round_number = 4;

-- Round 5 — no longer a numeric reproduction. Now an SCQA synthesis owned by the
-- Team Lead, graded on synthesis quality (keyword check on the Complication field),
-- so it is FREE_TEXT: outcome is not correct/incorrect.
UPDATE sim2_answer_key
   SET answer_type = 'FREE_TEXT',
       canonical_answer = 'SCQA synthesis - graded on quality, no fixed number',
       question = 'Synthesise your findings from Rounds 1-4 into an SCQA brief for the Board: Situation, Complication, Question, Answer. Owned and presented by the Team Lead.'
 WHERE simulation_id = sim AND round_number = 5;

END $$;
