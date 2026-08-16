-- ═══════════════════════════════════════════════════════════════════════════
-- Sim 2 v6 — content/timing changes from Meridian_QBR_Final_v6.docx.
-- (Per-field partial-credit scoring is in the Java layer; this file is DB content.)
-- ═══════════════════════════════════════════════════════════════════════════
DO $$
DECLARE sim uuid := '5116d200-0000-4000-a000-000000000002';
BEGIN

-- Round 1: 20 minutes total, mid-round duplicate twist fires at minute 9 (was 22 / 11).
UPDATE rounds SET duration_minutes = 20 WHERE simulation_id = sim AND round_number = 1;

UPDATE artifacts a SET open_offset_min = 0, expiry_offset_min = 20
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 1 AND a.artifact_type = 'BOARD_MEMO';

UPDATE artifacts a SET open_offset_min = 9, expiry_offset_min = 20
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 1 AND a.artifact_type = 'SCREEN_FLASH';

END $$;
