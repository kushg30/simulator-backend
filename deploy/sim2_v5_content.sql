-- ═══════════════════════════════════════════════════════════════════════════
-- Sim 2 v5 — realign all STUDENT-FACING CONTENT to the v5 documents:
--   * Round 2 reframed from a binary (training/market) to four fishbone
--     categories (People/Process/Market/Resource).
--   * Reference wiki was v1-era: FX/currency, product categories, PinCodes, a
--     non-existent Round 6, "submitted by the Team Lead", and per-round Excel
--     guides for the OLD round designs — none of which match the v5 serial-date
--     feed, the 10 office products, per-round ownership, or the 5-round script.
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE sim uuid := '5116d200-0000-4000-a000-000000000002';
BEGIN

-- ── Round 2 memo + Emergency Board Call: four-category framing ──────────────
UPDATE artifacts a SET payload = jsonb_set(
  jsonb_set(a.payload, '{title}', to_jsonb('Why did West miss its target?'::text)),
  '{body}', to_jsonb($t$West region missed its Q1 revenue target. I need the root cause, not a guess. Work it across the fishbone categories - People, Process, Market or Resource - and defend your call with a number: the attainment gap between West and the rest of the network. The store-level training data is attached.$t$::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 2 AND a.artifact_type = 'BOARD_MEMO';

UPDATE artifacts a SET payload = jsonb_set(a.payload, '{body}', to_jsonb(
  $t$One line - what is the single root cause behind West, and how confident are you in it?$t$::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 2 AND a.artifact_type = 'SCREEN_FLASH';

-- ── FACTS ───────────────────────────────────────────────────────────────────
-- Currency is irrelevant in v5 (no FX anywhere in the feeds).
DELETE FROM sim2_wiki_entries WHERE simulation_id = sim AND section = 'FACTS' AND title = 'Currency (FX Reference)';

UPDATE sim2_wiki_entries SET title = 'Products', body =
$t$Ten products appear in the feed: Notebook Set, Webcam HD, Desk Lamp, Whiteboard, USB-C Hub, Wireless Mouse, Laptop Charger, Bluetooth Speaker, Mechanical Keyboard, Office Chair.
There are no category, region or currency fields on the transactions - grade on the product only.$t$
WHERE simulation_id = sim AND section = 'FACTS' AND title = 'Product categories';

UPDATE sim2_wiki_entries SET body =
$t$Only the Round 2 store dataset carries regions:
West = STR03 (Mumbai) + STR04 (Pune)
South = STR01 (Hyderabad) + STR02 (Bangalore)
International = STR05 (Dubai) + STR06 (Singapore), online only
Round 2 compares West against the rest of the network. The Round 1 / Round 3 transaction feeds have no region field.$t$
WHERE simulation_id = sim AND section = 'FACTS' AND title = 'Regions';

UPDATE sim2_wiki_entries SET body =
$t$Round 2 store directory (training vs attainment):
STR01 - Hyderabad (South)
STR02 - Bangalore (South)
STR03 - Mumbai (West)
STR04 - Pune (West)
STR05 - Dubai (International, online)
STR06 - Singapore (International, online)
Each store has ManagerTrainingHours and RevenueAttainmentPct (100 = hit target).$t$
WHERE simulation_id = sim AND section = 'FACTS' AND title = 'Store directory';

UPDATE sim2_wiki_entries SET body =
$t$Rounds 1-4 carry a confidence tag: High / Medium / Low.
It is graded against whether you were right - being confidently wrong scores worse than being unsure and wrong. Tag honestly.
Round 5 (the synthesis) has no confidence tag.$t$
WHERE simulation_id = sim AND section = 'FACTS' AND title = 'Confidence tag';

-- ── FAQ: submission ownership is per-round, not the Team Lead ────────────────
UPDATE sim2_wiki_entries SET body =
$t$No. Each round is submitted once, by the role that owns it:
Round 1 - Data Quality Analyst
Round 2 - Diagnostics Analyst
Round 3 - Automation Analyst
Round 4 - Visualization Analyst
Round 5 - Team Lead
Agree as a team before the owner submits - it cannot be changed afterwards.$t$
WHERE simulation_id = sim AND section = 'FAQ' AND title = 'Can we change our answer after submitting a round?';

-- ── FUNCTIONS: rewrite per-round guides for the v5 tasks; drop Round 6 ───────
DELETE FROM sim2_wiki_entries WHERE simulation_id = sim AND section = 'FUNCTIONS' AND round_number = 6;

UPDATE sim2_wiki_entries SET title = 'Round 1 · Parsing the raw feed', body =
$t$Each row is one string: SerialDate-Product-Price-Quantity.
- FIND / MID / LEFT / RIGHT / LEN - split the string on the hyphens
- VALUE - turn the price and quantity text into real numbers
- The date is an Excel serial number (e.g. 46043) - format the cell as a date if you need it
- SUMPRODUCT or SUMIFS - total Price x Quantity for one product
- EXACT - catch exact-duplicate rows$t$
WHERE simulation_id = sim AND section = 'FUNCTIONS' AND round_number = 1;

UPDATE sim2_wiki_entries SET title = 'Round 2 · Comparing stores', body =
$t$Reading the store-level training data:
- AVERAGEIF(Region,"West",...) - average training hours / attainment for West vs the rest
- CORREL - the strength of the training-hours to attainment relationship
- Attainment gap = rest-of-network average minus West average (percentage points)
- Frame the cause with the fishbone: People / Process / Market / Resource$t$
WHERE simulation_id = sim AND section = 'FUNCTIONS' AND round_number = 2;

UPDATE sim2_wiki_entries SET title = 'Round 3 · Combine + automate', body =
$t$Combining the two months and recording the macro:
- Record Macro - capture the combine steps, then read the generated code
- Append Round 3's rows below Round 1's into one combined table
- Row count and total Price x Quantity are taken across every combined row - duplicates are kept, do not deduplicate
- Sub ... End Sub, Range, Cells - the building blocks of the recorded macro$t$
WHERE simulation_id = sim AND section = 'FUNCTIONS' AND round_number = 3;

UPDATE sim2_wiki_entries SET title = 'Round 4 · The visual story', body =
$t$Answering with a chart (Tableau or Power BI - your choice):
- Count orders per product to find the most-ordered
- MONTH() on the serial date to bucket orders by month
- A bar / column chart for products, a line / column chart for the monthly trend
- Chart type is self-declared on submission and spot-checked live$t$
WHERE simulation_id = sim AND section = 'FUNCTIONS' AND round_number = 4;

UPDATE sim2_wiki_entries SET title = 'Round 5 · The Board brief (SCQA)', body =
$t$No formulas - this is a synthesis of Rounds 1-4.
- Situation: where the business stands
- Complication: what your analysis uncovered - reference the specific findings and figures from the earlier rounds
- Question: the decision the Board now faces
- Answer: your recommendation
You present it live to the Board - 120 seconds, format is your call.$t$
WHERE simulation_id = sim AND section = 'FUNCTIONS' AND round_number = 5;

END $$;
