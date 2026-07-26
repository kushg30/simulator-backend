-- ============================================================================
-- Patch: Simulator 1 (Leadership Judgment — ANP Phoenix) Round 1 artifact
-- open-offset times, corrected to match the scenario script
-- (Scenario_Leadership Judgment Simulator_v0.2, "Timeline overview").
--
-- Bug: every R1 artifact was seeded with open_offset_min = 0, so the whole
-- round's information dumped at T+0 instead of releasing in the staggered
-- sequence the scenario prescribes (T+0 … T+27). Expiry offsets were already
-- correct, so only open_offset_min changes here — plus the final CEO decision,
-- whose window is widened to T+27 … T+30 (round end) so it stays submittable.
--
-- Idempotent: safe to run more than once. Keyed on artifact_id, so it targets
-- exactly the Simulator 1 Round 1 artifacts and nothing else.
-- Run against the live database (e.g. Neon) once; the seed file carries the
-- same values for fresh loads.
-- ============================================================================

BEGIN;

-- T+0  CRO Note (displayed to all) — unchanged, but set explicitly for clarity.
UPDATE public.artifacts SET open_offset_min = 0  WHERE artifact_id = '39055c5f-f87f-4b42-a9de-936d7b966631';
-- T+4  Finance Memo (CFO)
UPDATE public.artifacts SET open_offset_min = 4  WHERE artifact_id = '979a48d0-bae8-4df9-b503-7d09c10513f8';
-- T+5  Finance Clarification (CEO, conditional)
UPDATE public.artifacts SET open_offset_min = 5  WHERE artifact_id = '8a9423d1-6a6b-4027-a8ec-7c6ec4f23032';
-- T+6  #data-integrity Slack thread (Head of Engineering)
UPDATE public.artifacts SET open_offset_min = 6  WHERE artifact_id = 'cb6739ed-af0c-4905-9c24-695165d8b1cc';
-- T+7  Diagnostic Summary (Head of Engineering, conditional)
UPDATE public.artifacts SET open_offset_min = 7  WHERE artifact_id = 'c60c896f-2c21-4bf4-a08b-e3b80031ae63';
-- T+8  Ops Dashboard Snapshot (Head of Operations)
UPDATE public.artifacts SET open_offset_min = 8  WHERE artifact_id = '6f0cc855-4313-4235-b5ef-2250481bfe74';
-- T+10 Board Message (CEO)
UPDATE public.artifacts SET open_offset_min = 10 WHERE artifact_id = 'ddf4035d-c7ee-4ca5-bae0-21d282363447';
-- T+13 Pulse & Exit Interview Snapshot (CHRO)
UPDATE public.artifacts SET open_offset_min = 13 WHERE artifact_id = '46b6212f-280d-488d-8980-426914e09877';
-- T+16 Calendar Conflict (CEO)
UPDATE public.artifacts SET open_offset_min = 16 WHERE artifact_id = '92f458fe-e9fb-435c-bf8c-86fa1e64546b';
-- T+20 Investor Draft (CFO & Head of Product)
UPDATE public.artifacts SET open_offset_min = 20 WHERE artifact_id = '51a34cee-8ca2-4c82-9032-4396226a27fa';
-- T+23 Internal Tagging Check (Head of Engineering & Head of Operations)
UPDATE public.artifacts SET open_offset_min = 23 WHERE artifact_id = 'fda235ee-6aab-434a-87f5-d7883d4891c8';
-- T+25 Silence Check (screen flash, all)
UPDATE public.artifacts SET open_offset_min = 25 WHERE artifact_id = '1d842ccd-0574-4829-ae64-90b3584eaee2';
-- T+27 CEO submits the Round 1 decision — appears at T+27, submittable to round end (T+30).
UPDATE public.artifacts SET open_offset_min = 27, expiry_offset_min = 30
 WHERE artifact_id = 'f6897622-60dc-4a8c-9141-18fed2ce091a';

-- ----------------------------------------------------------------------------
-- Role-code alignment. Role selection and simulation_roles use OPERATIONS and
-- PRODUCT, but three artifacts targeted HEAD_OF_OPERATIONS / HEAD_OF_PRODUCT in
-- allowed_roles, so those seats never saw their own artifacts. Align the
-- artifact codes to the roles participants actually hold. Content-based and
-- ID-independent; only Simulation 1 artifacts carry these codes (HEAD_OF_
-- ENGINEERING is intentionally left unchanged).
-- ----------------------------------------------------------------------------
UPDATE public.artifacts
   SET allowed_roles = replace(allowed_roles::text, 'HEAD_OF_OPERATIONS', 'OPERATIONS')::jsonb
 WHERE allowed_roles::text LIKE '%HEAD_OF_OPERATIONS%';

UPDATE public.artifacts
   SET allowed_roles = replace(allowed_roles::text, 'HEAD_OF_PRODUCT', 'PRODUCT')::jsonb
 WHERE allowed_roles::text LIKE '%HEAD_OF_PRODUCT%';

COMMIT;
