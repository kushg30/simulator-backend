-- ============================================================================
-- Simulator 2 (Meridian Retail QBR) — v3 migration, PHASE 3: engagement.
--
-- Run AFTER v3 phases 1 & 2. Idempotent.
--   * Emergency Board Call (R2, T+10) reworded to the v3 training/market prompt
--     and restricted to the Team Lead (only they respond).
--   * (Breaking News personalisation is code-side — no schema change.)
--
-- Board Call artifact: 5116d200-0002-4000-a000-000000000024 (Round 2)
-- ============================================================================

BEGIN;

UPDATE public.artifacts
   SET allowed_roles = '["TEAM_LEAD"]'::jsonb,
       payload = '{"tab":"decisions","title":"Emergency Board Call","body":"One word — is West a training problem, or a market problem?","board_call":true}'::jsonb
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000024';

COMMIT;
