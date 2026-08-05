-- ============================================================================
-- Simulator 2 (Meridian Retail QBR) — v2 migration, PHASE 1: structure.
--
-- Idempotent. Roles are renamed to the v2 set (codes kept so existing
-- allowed_roles / owner_role references keep working — only display names
-- change), round durations updated, Round 6 removed (v2 is five rounds), and
-- the simulation's round count / description corrected.
--
-- Sim 2 simulation_id: 5116d200-0000-4000-a000-000000000002
-- Round 6 round_id:    5116d200-0001-4000-a000-000000000006
--
-- Phases 2+ (answer key, round content, engagement features) follow separately.
-- ============================================================================

BEGIN;

-- ------------------------------------------------ 1. role display names (v2)
-- Codes unchanged; only what students see. R3/R4/R5 owners map to these codes.
UPDATE public.simulation_roles SET display_name = 'Reporting Analyst'
 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND role_code = 'REPORTING_DASHBOARD_ANALYST';
UPDATE public.simulation_roles SET display_name = 'Dashboard Analyst'
 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND role_code = 'PEOPLE_ANALYTICS_ASSOCIATE';
UPDATE public.simulation_roles SET display_name = 'BI Associate'
 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND role_code = 'AUTOMATION_BI_ASSOCIATE';

-- ------------------------------------------------ 2. round durations (v2)
UPDATE public.rounds SET duration_minutes = 20 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND round_number = 1;
UPDATE public.rounds SET duration_minutes = 20 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND round_number = 2;
UPDATE public.rounds SET duration_minutes = 25 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND round_number = 3;
UPDATE public.rounds SET duration_minutes = 20 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND round_number = 4;
UPDATE public.rounds SET duration_minutes = 20 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND round_number = 5;

-- ------------------------------------------------ 3. remove Round 6 (v2 = 5 rounds)
-- Delete dependents first (cascade order); guarded subqueries so re-running is a no-op.
DELETE FROM public.decision_events WHERE artifact_id IN
  (SELECT artifact_id FROM public.artifacts WHERE round_id = '5116d200-0001-4000-a000-000000000006');
DELETE FROM public.decision_options WHERE decision_id IN
  (SELECT d.decision_id FROM public.decisions d JOIN public.artifacts a ON a.artifact_id = d.artifact_id
    WHERE a.round_id = '5116d200-0001-4000-a000-000000000006');
DELETE FROM public.artifact_conditions WHERE artifact_id IN
  (SELECT artifact_id FROM public.artifacts WHERE round_id = '5116d200-0001-4000-a000-000000000006');
DELETE FROM public.decisions WHERE artifact_id IN
  (SELECT artifact_id FROM public.artifacts WHERE round_id = '5116d200-0001-4000-a000-000000000006');
DELETE FROM public.artifacts WHERE round_id = '5116d200-0001-4000-a000-000000000006';
DELETE FROM public.sim2_round_state WHERE round_number = 6;
DELETE FROM public.sim2_answer_key
 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND round_number = 6;
DELETE FROM public.rounds WHERE round_id = '5116d200-0001-4000-a000-000000000006';

-- ------------------------------------------------ 4. simulation metadata
UPDATE public.simulations
   SET total_rounds = 5,
       description  = 'Five-round analytics engagement: clean, analyse and present a Quarterly Business Review the Board can trust, filter and act on.'
 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002';

COMMIT;
