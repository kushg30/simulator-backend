-- ============================================================================
-- Simulator 2 (Meridian Retail QBR) — v4 migration, PHASE 1: roles & structure.
--
-- Idempotent. v4 is a team of 5 (BI Associate removed; Round 5 is now the Team
-- Lead's, solo). Round 2 owner renamed Diagnostics Analyst. R1 runs 22 min
-- (twist at minute 11).
--
-- Sim 2 id: 5116d200-0000-4000-a000-000000000002
-- ============================================================================

BEGIN;

-- R2 owner rename
UPDATE public.simulation_roles SET display_name = 'Diagnostics Analyst'
 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND role_code = 'CATEGORY_REGIONAL_ANALYST';

-- Team of 5: remove the BI Associate role (Round 5 folds into the Team Lead).
DELETE FROM public.simulation_roles
 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND role_code = 'AUTOMATION_BI_ASSOCIATE';

-- Round 5 is now owned/submitted by the Team Lead.
UPDATE public.artifacts
   SET payload = jsonb_set(payload, '{owner_role}', '"TEAM_LEAD"')
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000051';

-- v4 timing: Round 1 is 22 minutes (twist fires at minute 11).
UPDATE public.rounds SET duration_minutes = 22
 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND round_number = 1;

COMMIT;
