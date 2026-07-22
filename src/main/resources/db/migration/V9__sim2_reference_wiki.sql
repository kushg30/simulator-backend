-- ============================================================================
-- Reference wiki (spec section 9F) — in-platform, always available.
--
-- Three sections:
--   FUNCTIONS : a function quick-reference scoped to each round's skill anchor,
--               so Round 4 surfaces DAX and not VBA.
--   FACTS     : a company fact sheet (stores, categories, FX) so a student is not
--               blocked by forgetting a detail already given in the dataset.
--   FAQ       : faculty-maintained, editable, carried across cohorts. Seeded with
--               one example; faculty add/edit/remove the rest.
--
-- This is self-serve reference, not a shortcut: nothing here reveals a canonical
-- answer. It exists to keep the facilitator out of low-value clarifying questions
-- during the clock.
--
-- Idempotent: safe to re-run.
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS sim2_wiki_entries (
    entry_id      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    simulation_id UUID    NOT NULL,
    section       TEXT    NOT NULL CHECK (section IN ('FUNCTIONS','FACTS','FAQ')),
    round_number  INTEGER,          -- set for FUNCTIONS (the round it applies to)
    title         TEXT    NOT NULL,
    body          TEXT    NOT NULL,
    ordinal       INTEGER NOT NULL DEFAULT 0,
    editable      BOOLEAN NOT NULL DEFAULT false,  -- FAQ entries are editable
    created_at    TIMESTAMP NOT NULL DEFAULT now(),
    updated_at    TIMESTAMP NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_sim2_wiki_sim ON sim2_wiki_entries (simulation_id, section, round_number, ordinal);

-- Reseed the non-editable sections (leave faculty-authored FAQ untouched).
DELETE FROM sim2_wiki_entries
WHERE simulation_id = '5116d200-0000-4000-a000-000000000002'
  AND section IN ('FUNCTIONS','FACTS');

-- ---------------------------------------------------------------------------
-- FUNCTIONS — one card per round, matching the round's skill anchor.
-- ---------------------------------------------------------------------------
INSERT INTO sim2_wiki_entries (simulation_id, section, round_number, title, body, ordinal) VALUES
('5116d200-0000-4000-a000-000000000002','FUNCTIONS',1,'Round 1 · Text & Logical functions',
 E'Cleaning text and applying rules:\n'
 || E'• TRIM, CLEAN — strip stray spaces and non-printing characters\n'
 || E'• PROPER / UPPER / LOWER — normalise casing on names\n'
 || E'• LEFT, RIGHT, MID, LEN, FIND, SUBSTITUTE — pull apart and fix strings\n'
 || E'• EXACT — case-sensitive comparison when checking duplicates\n'
 || E'• DATEVALUE, TEXT, DATE — convert mixed date formats to real dates\n'
 || E'• IF, IFS, AND, OR, NOT — conditional logic\n'
 || E'• IFERROR — trap lookups/conversions that fail\n'
 || E'• SUMIFS, COUNTIFS — totals with conditions (e.g. by region)',0),

('5116d200-0000-4000-a000-000000000002','FUNCTIONS',2,'Round 2 · Lookup/Reference & Statistical',
 E'Joining reference data and measuring:\n'
 || E'• VLOOKUP / XLOOKUP — pull a value from a reference table by key\n'
 || E'• INDEX + MATCH — flexible two-way lookup\n'
 || E'• SUMIFS, AVERAGEIFS, COUNTIFS — conditional aggregation\n'
 || E'• SUMPRODUCT — weighted totals across columns\n'
 || E'• Margin % = (Revenue − Cost) / Revenue — compute per row, then aggregate\n'
 || E'• Apply per-row rules (e.g. a channel-specific price) BEFORE aggregating',0),

('5116d200-0000-4000-a000-000000000002','FUNCTIONS',3,'Round 3 · Tables, PivotTables & Slicers',
 E'Building an interactive one-pager:\n'
 || E'• Format as Table (Ctrl+T) — structured references, auto-expand\n'
 || E'• PivotTable — summarise by region / category / channel\n'
 || E'• PivotChart — a visual tied to the pivot\n'
 || E'• Slicers and Timelines — let the Board filter live\n'
 || E'• GETPIVOTDATA — reference a pivot cell safely\n'
 || E'• Growth = this quarter − prior quarter, per dimension',0),

('5116d200-0000-4000-a000-000000000002','FUNCTIONS',4,'Round 4 · Data Models & DAX',
 E'Relating tables and measuring:\n'
 || E'• Data Model — add tables, create relationships (Manage Relationships)\n'
 || E'• A relationship needs a matching KEY on both sides (Store ID, not name)\n'
 || E'• CALCULATE — a measure under filter context\n'
 || E'• DIVIDE(num, den) — safe division\n'
 || E'• RELATED / RELATEDTABLE — pull across a relationship\n'
 || E'• MEDIANX, AVERAGEX — iterate a table for a statistic\n'
 || E'• Measures (dynamic) vs calculated columns (row-by-row)',0),

('5116d200-0000-4000-a000-000000000002','FUNCTIONS',5,'Round 5 · Power BI',
 E'Porting the model so the Board can self-serve:\n'
 || E'• Get Data — bring the workbook/model into Power BI\n'
 || E'• Model view — recreate the relationships\n'
 || E'• DAX measures — same logic as the Data Model\n'
 || E'• Visuals + slicers — an explorable report\n'
 || E'• Reproduce a known figure exactly to prove the port is faithful',0),

('5116d200-0000-4000-a000-000000000002','FUNCTIONS',6,'Round 6 · VBA & Macros',
 E'Automating a monthly deliverable:\n'
 || E'• Record Macro — capture steps, then read the generated code\n'
 || E'• Sub ... End Sub — a macro procedure\n'
 || E'• Range, Cells, Worksheets — refer to data in code\n'
 || E'• ThisWorkbook.RefreshAll — refresh queries/pivots\n'
 || E'• ExportAsFixedFormat / SaveAs — export the report\n'
 || E'• A macro that breaks next month is worse than none — keep it robust',0);

-- ---------------------------------------------------------------------------
-- FACTS — restating detail already in the dataset, so nobody is blocked by a
-- forgotten reference. No answers here.
-- ---------------------------------------------------------------------------
INSERT INTO sim2_wiki_entries (simulation_id, section, round_number, title, body, ordinal) VALUES
('5116d200-0000-4000-a000-000000000002','FACTS',NULL,'Store directory',
 E'STR01 — Hyderabad (South, India, INR)\n'
 || E'STR02 — Bangalore (South, India, INR)\n'
 || E'STR03 — Mumbai (West, India, INR)\n'
 || E'STR04 — Pune (West, India, INR)\n'
 || E'STR05 — Dubai (International, online only, AED)\n'
 || E'STR06 — Singapore (International, online only, SGD)',0),

('5116d200-0000-4000-a000-000000000002','FACTS',NULL,'Regions',
 E'South = STR01 + STR02 (Hyderabad, Bangalore)\n'
 || E'West  = STR03 + STR04 (Mumbai, Pune)\n'
 || E'International = STR05 + STR06 (online only)\n'
 || E'PinCode prefix → region: 50/56 = South, 40/41 = West',1),

('5116d200-0000-4000-a000-000000000002','FACTS',NULL,'Product categories',
 E'Apparel · Beauty & Personal Care · Electronics Accessories · Footwear · Home & Living\n'
 || E'Prices are in the Product Master. A couple of SKUs carry a separate online-channel price.',2),

('5116d200-0000-4000-a000-000000000002','FACTS',NULL,'Currency (FX Reference)',
 E'1 AED = 22.50 INR\n'
 || E'1 SGD = 62.00 INR\n'
 || E'Quarter-end treasury rates. Only the two international online stores use non-INR currency.',3),

('5116d200-0000-4000-a000-000000000002','FACTS',NULL,'Confidence tag',
 E'Every round submission carries a confidence tag: High / Medium / Low.\n'
 || E'It is graded: being confidently wrong scores worse than being unsure and wrong. Tag honestly.',4);

-- ---------------------------------------------------------------------------
-- FAQ — one seeded example; faculty maintain the rest.
-- ---------------------------------------------------------------------------
INSERT INTO sim2_wiki_entries (simulation_id, section, round_number, title, body, ordinal, editable)
SELECT '5116d200-0000-4000-a000-000000000002','FAQ',NULL,
       'Can we change our answer after submitting a round?',
       'No. A round is submitted once, by the Team Lead. Decide together before you submit.',
       0, true
WHERE NOT EXISTS (
  SELECT 1 FROM sim2_wiki_entries
  WHERE simulation_id='5116d200-0000-4000-a000-000000000002' AND section='FAQ');

COMMIT;
