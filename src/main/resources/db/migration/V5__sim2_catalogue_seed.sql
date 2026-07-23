-- ============================================================================
-- Sample catalogue artifacts for Meridian Retail QBR.
--
-- These are the pre-authored, pre-vetted artifacts a facilitator can deploy
-- live from the console. Straight from the sample catalogue in the spec.
--
-- Tier rules enforced by the table itself:
--   CONTEXT -> flavour only, never scored, no canonical answer needed
--   SCORED  -> must carry a canonical answer, because the platform will not
--              grade a team against an answer nobody defined in advance
--
-- Idempotent: safe to re-run.
-- ============================================================================

BEGIN;

DELETE FROM catalogue_artifacts
WHERE simulation_id = '5116d200-0000-4000-a000-000000000002';

INSERT INTO catalogue_artifacts (simulation_id, round_number, title, content, tier,
                                 canonical_answer, effect)
VALUES
    ('5116d200-0000-4000-a000-000000000002', 1,
     'Finance confirms the currency conversion rates used',
     'Finance has confirmed the AED and SGD conversion rates in the FX Reference sheet are the '
  || 'quarter-end treasury rates. Use them as published; no further adjustment is needed.',
     'CONTEXT', NULL,
     'Removes ambiguity for a struggling team; no scoring impact'),

    ('5116d200-0000-4000-a000-000000000002', 2,
     'Marketing shares this quarter segment definitions',
     'Marketing has circulated the customer segment definitions used this quarter, for reference '
  || 'when discussing category performance.',
     'CONTEXT', NULL,
     'Light STP cross-course reinforcement, no scoring impact'),

    ('5116d200-0000-4000-a000-000000000002', 4,
     'Board asks for a one-line theory, not just the store name',
     'The Board would like one line on WHY that store is the outlier, not just which store it is.',
     'CONTEXT', NULL,
     'Adds an Insight Communication prompt without changing the graded answer'),

    ('5116d200-0000-4000-a000-000000000002', 4,
     'HR sends a partial ID-to-name mapping for 2 of the 4 stores',
     'HR has sent a partial mapping covering two of the four India stores. The remaining two still '
  || 'need to be reconciled by hand.',
     'SCORED', 'STR04',
     'Makes the join-key twist tractable for a team stuck at the halfway mark; canonical answer unchanged');

COMMIT;
