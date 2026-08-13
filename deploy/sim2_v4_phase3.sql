-- Simulator 2 v4 — PHASE 3a: Round 1 mid-round duplicate-transactions twist (minute 11).
-- Idempotent. R1 round: 5116d200-0001-4000-a000-000000000001
BEGIN;
-- R1 memo now runs the full 22 minutes
UPDATE public.artifacts SET expiry_offset_min = 22
 WHERE artifact_id = '5116d200-0002-4000-a000-000000000001';
-- Mid-round interrupt at T+11: check for duplicate transactions before locking.
INSERT INTO public.artifacts
  (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
VALUES
('5116d200-0002-4000-a000-000000000012','5116d200-0001-4000-a000-000000000001','SCREEN_FLASH',11,22,false,
 '{"tab":"inbox","from":"Head of Strategy","title":"One more thing before you lock this","body":"I have just heard some of these transactions might be logged twice somewhere in here. Check before you send me anything.","display_style":"FLASH"}'::jsonb, NULL)
ON CONFLICT (artifact_id) DO NOTHING;
COMMIT;
