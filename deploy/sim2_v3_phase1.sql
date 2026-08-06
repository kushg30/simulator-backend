-- ============================================================================
-- Simulator 2 (Meridian Retail QBR) — v3 migration, PHASE 1: roles & timing.
--
-- Idempotent. Codes unchanged (so allowed_roles / owner_role keep working);
-- only display names change. v3 renames the round owners:
--   Category & Regional Analyst -> Insights & Root-Cause Analyst (R2)
--   Reporting Analyst           -> Automation Analyst            (R3)
--   Dashboard Analyst           -> Visualization Analyst         (R4)
-- and swaps R3/R4 durations (R3 20, R4 25).
--
-- Sim 2 id: 5116d200-0000-4000-a000-000000000002
-- ============================================================================

BEGIN;

UPDATE public.simulation_roles SET display_name = 'Insights & Root-Cause Analyst'
 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND role_code = 'CATEGORY_REGIONAL_ANALYST';
UPDATE public.simulation_roles SET display_name = 'Automation Analyst'
 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND role_code = 'REPORTING_DASHBOARD_ANALYST';
UPDATE public.simulation_roles SET display_name = 'Visualization Analyst'
 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND role_code = 'PEOPLE_ANALYTICS_ASSOCIATE';

-- v3 durations: R1 20, R2 20, R3 20, R4 25, R5 20 (R3 25->20, R4 20->25).
UPDATE public.rounds SET duration_minutes = 20 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND round_number = 3;
UPDATE public.rounds SET duration_minutes = 25 WHERE simulation_id = '5116d200-0000-4000-a000-000000000002' AND round_number = 4;

COMMIT;
