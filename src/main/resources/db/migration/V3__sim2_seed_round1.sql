-- ============================================================================
-- Phase 1 — Simulator 2 content seed: Meridian Retail QBR, Round 1
--
-- Sources of truth:
--   * DESIGN  : "Meridian Retail QBR Simulation" script PDF
--   * DATA    : ANSWER_KEY_FACULTY_ONLY.xlsx + Meridian_Retail_Master_Dataset.xlsx
--   * readme.txt is STALE and was discarded (it claimed 900 rows and R1 = 1,282,261)
--
-- The Round-1 answer (1,302,602) was verified by recomputing from the real
-- 850-row dataset: exclude the 18 voided TXNs, then either group by Region
-- 'South' AFTER backfilling the 73 blank-region rows, or group by StoreID
-- STR01+STR02 (which needs no backfill). Both paths give 1,302,602.
-- Without the backfill a Region filter yields 1,186,515 — hence the memo keeps
-- the backfill instruction.
--
-- Idempotent: safe to re-run.
-- ============================================================================

BEGIN;

-- Fixed IDs so re-running is stable and the frontend can be pointed at them.
-- Simulation : 5116d200-0000-4000-a000-000000000002
-- Round 1    : 5116d200-0001-4000-a000-000000000001

-- ---------------------------------------------------------------------------
-- 1. Simulation
-- ---------------------------------------------------------------------------
INSERT INTO simulations (simulation_id, name, description, total_rounds, duration_minutes)
VALUES ('5116d200-0000-4000-a000-000000000002',
        'Meridian Retail QBR',
        'Six-round analytics engagement: clean, analyse and present a Quarterly Business Review the Board can trust, filter and act on.',
        6, 180)
ON CONFLICT (simulation_id) DO UPDATE
   SET name = EXCLUDED.name,
       description = EXCLUDED.description,
       total_rounds = EXCLUDED.total_rounds,
       duration_minutes = EXCLUDED.duration_minutes;

-- ---------------------------------------------------------------------------
-- 2. Roles (Team Lead is the lead: coordinates and submits every round)
-- ---------------------------------------------------------------------------
INSERT INTO simulation_roles (simulation_id, role_code, display_name, ordinal, is_lead)
VALUES
    ('5116d200-0000-4000-a000-000000000002','TEAM_LEAD',                  'Team Lead',                    1, true),
    ('5116d200-0000-4000-a000-000000000002','DATA_QUALITY_ANALYST',       'Data Quality Analyst',         2, false),
    ('5116d200-0000-4000-a000-000000000002','CATEGORY_REGIONAL_ANALYST',  'Category & Regional Analyst',  3, false),
    ('5116d200-0000-4000-a000-000000000002','REPORTING_DASHBOARD_ANALYST','Reporting & Dashboard Analyst',4, false),
    ('5116d200-0000-4000-a000-000000000002','PEOPLE_ANALYTICS_ASSOCIATE', 'People Analytics Associate',   5, false),
    ('5116d200-0000-4000-a000-000000000002','AUTOMATION_BI_ASSOCIATE',    'Automation & BI Associate',    6, false)
ON CONFLICT (simulation_id, role_code) DO UPDATE
   SET display_name = EXCLUDED.display_name,
       ordinal = EXCLUDED.ordinal,
       is_lead = EXCLUDED.is_lead;

-- ---------------------------------------------------------------------------
-- 3. Round 1 — "Clean this before I trust a single number in it" (18 minutes)
-- ---------------------------------------------------------------------------
INSERT INTO rounds (round_id, simulation_id, round_number, duration_minutes)
VALUES ('5116d200-0001-4000-a000-000000000001',
        '5116d200-0000-4000-a000-000000000002', 1, 18)
ON CONFLICT (simulation_id, round_number) DO UPDATE
   SET duration_minutes = EXCLUDED.duration_minutes;

-- Re-seeding: clear this round's artifacts (cascades to decisions/options).
DELETE FROM artifacts WHERE round_id = '5116d200-0001-4000-a000-000000000001';

-- ---------------------------------------------------------------------------
-- 3a. T+0 Board memo — visible to everyone, no decision.
-- ---------------------------------------------------------------------------
INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min,
                       expected_action, payload, allowed_roles)
VALUES (
    '5116d200-0002-4000-a000-000000000001',
    '5116d200-0001-4000-a000-000000000001',
    'BOARD_MEMO', 0, 18, false,
    jsonb_build_object(
        'tab',   'inbox',
        'from',  'Head of Strategy',
        'title', 'Clean this before I trust a single number in it',
        'body',  'Sales data from 6 stores has landed. Three things before you touch it. '
              || '(1) Dates are logged in three different formats. '
              || '(2) Some customer names are duplicated with small typos — check for these; do not assume every repeated name is a distinct person, or vice versa. '
              || '(3) Currency is mixed: our UAE and Singapore online orders are logged in AED and SGD, not INR. Use the FX Reference sheet in the master file to convert. '
              || 'Separately: 73 rows are missing a Region tag. These are India online orders and can be backfilled using the PinCode-to-Region mapping. '
              || 'The Board will notice if the clean file handed off next round still has blanks in it.',
        'files', jsonb_build_array('Meridian_Retail_Master_Dataset.xlsx'),
        'owner_role', 'DATA_QUALITY_ANALYST'
    ),
    NULL
);

-- ---------------------------------------------------------------------------
-- 3b. T+8 Twist — voided transactions. Explicit micro-decision, owned by the
--     Data Quality Analyst. The chosen option drives the R1 -> R2 conditional.
--
--     VISIBILITY vs PERMISSION are deliberately different here:
--       * artifacts.allowed_roles = NULL  -> the whole team SEES the twist.
--         Meridian is a collaborative engagement; unlike Simulation 1, its
--         round tables carry no Roles column, so artifacts are not gated.
--       * decisions.allowed_roles         -> only the round owner (Data Quality
--         Analyst) and the Team Lead may ANSWER it.
-- ---------------------------------------------------------------------------
INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min,
                       expected_action, payload, allowed_roles)
VALUES (
    '5116d200-0002-4000-a000-000000000002',
    '5116d200-0001-4000-a000-000000000001',
    'TWIST', 8, 18, true,
    jsonb_build_object(
        'tab',   'decisions',
        'from',  'Finance Operations',
        'title', 'Correction file: voided transactions',
        'body',  'A correction file has arrived: 2 stores had voided transactions still sitting in their totals. '
              || '18 transaction IDs are affected. Decide how to handle them before you report a number.',
        'files', jsonb_build_array('Round1_Correction_VoidedTransactions.xlsx'),
        'owner_role', 'DATA_QUALITY_ANALYST'
    ),
    NULL  -- visible to the whole team; answering is restricted below
);

INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, options, allowed_roles)
VALUES (
    '5116d200-0003-4000-a000-000000000002',
    '5116d200-0002-4000-a000-000000000002',
    'EXPLICIT', false,
    jsonb_build_array(
        jsonb_build_object('id','EXCLUDE_VIA_FORMULA','label','Exclude them via formula'),
        jsonb_build_object('id','DELETE_ROWS',        'label','Delete the rows'),
        jsonb_build_object('id','LEAVE_AND_FLAG',     'label','Leave them and flag for the Board')
    ),
    jsonb_build_array('DATA_QUALITY_ANALYST','TEAM_LEAD')
);

-- decision_options carries Sim-1 delta columns (NOT NULL). Sim 2 does not use
-- them and never calls applyConstructDeltas, so they are seeded as 0.
INSERT INTO decision_options (decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES
    ('5116d200-0003-4000-a000-000000000002','EXCLUDE_VIA_FORMULA',0,0,0,0),
    ('5116d200-0003-4000-a000-000000000002','DELETE_ROWS',        0,0,0,0),
    ('5116d200-0003-4000-a000-000000000002','LEAVE_AND_FLAG',     0,0,0,0);

-- ---------------------------------------------------------------------------
-- 4. Answer key (FACULTY ONLY).
--    Exact integer match — the key states no tolerance for Round 1.
-- ---------------------------------------------------------------------------
INSERT INTO sim2_answer_key (simulation_id, round_number, question, canonical_answer,
                             answer_type, tolerance_abs, tolerance_pct, grading_notes)
VALUES (
    '5116d200-0000-4000-a000-000000000002', 1,
    'What is the reconciled total sales value (in INR) for the South region after this round''s corrections?',
    '1302602', 'NUMERIC', NULL, NULL,
    'Excludes the 18 voided TXNs (9 in STR02/South, 9 in STR04/West). South = STR01 + STR02, both INR, '
 || 'so FX conversion does not affect this figure. Verified by recomputation: Region=South WITH the 73-row '
 || 'PinCode backfill = 1302602 (391 rows); WITHOUT backfill = 1186515 (359 rows); grouping by StoreID '
 || 'STR01+STR02 = 1302602 with no backfill needed. Raw UnitPrice equals Product_Master list price for all '
 || '732 INR rows. The AP-104/EA-501 online-channel deduction is a Round-2 twist and must NOT be applied here.'
)
ON CONFLICT (simulation_id, round_number) DO UPDATE
   SET question = EXCLUDED.question,
       canonical_answer = EXCLUDED.canonical_answer,
       answer_type = EXCLUDED.answer_type,
       tolerance_abs = EXCLUDED.tolerance_abs,
       tolerance_pct = EXCLUDED.tolerance_pct,
       grading_notes = EXCLUDED.grading_notes;

COMMIT;
