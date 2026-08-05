-- ============================================================================
-- Simulator 2 (Meridian Retail QBR) — v2 migration, PHASE 3: engagement.
--
-- Run AFTER phase 1 & 2. Idempotent.
--   * sim2_broadcast   — facilitator broadcasts (Breaking News) per simulation.
--   * sim2_board_call  — team one-line responses to the Emergency Board Call.
--   * Emergency Board Call artifact seeded into Round 2 at T+10.
--
-- Sim 2 id: 5116d200-0000-4000-a000-000000000002 ; R2 round: 5116d200-0001-...002
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS public.sim2_broadcast (
    broadcast_id  uuid NOT NULL DEFAULT gen_random_uuid(),
    simulation_id uuid NOT NULL,
    kind          text NOT NULL DEFAULT 'BREAKING_NEWS',
    message       text NOT NULL,
    created_by    text,
    created_at    timestamp without time zone NOT NULL DEFAULT now(),
    CONSTRAINT pk_sim2_broadcast PRIMARY KEY (broadcast_id)
);
CREATE INDEX IF NOT EXISTS idx_sim2_broadcast_sim ON public.sim2_broadcast (simulation_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.sim2_board_call (
    run_id         uuid    NOT NULL,
    round_number   integer NOT NULL,
    participant_id uuid,
    response       text    NOT NULL,
    created_at     timestamp without time zone NOT NULL DEFAULT now(),
    CONSTRAINT pk_sim2_board_call PRIMARY KEY (run_id, round_number)
);

-- Emergency Board Call — Round 2, T+10, shown to all, ungraded one-line response.
INSERT INTO public.artifacts
  (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
VALUES
('5116d200-0002-4000-a000-000000000024','5116d200-0001-4000-a000-000000000002','SCREEN_FLASH',10,20,false,
 '{"tab":"decisions","title":"Emergency Board Call","body":"One word — is this a pricing problem or a data problem?","board_call":true}'::jsonb, NULL)
ON CONFLICT (artifact_id) DO NOTHING;

COMMIT;
