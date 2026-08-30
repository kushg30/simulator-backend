-- Sim 1 platform features from the updated script:
--   1.2  News interrupt  -> sim1_news broadcasts (round-scoped; slide the schedule while active)
--   1.7  CEO timeout     -> faculty_actions gains a TIMEOUT action type (auto-advance marker)
--   1.2  faculty log      -> faculty_actions gains a NEWS action type
-- 1.10 (interstitial) and the timeout derivation need no schema: a COMPLETE round with no final
--       decision event is, by construction, a timed-out round.
BEGIN;

-- 1.2 News interrupt broadcasts. One row per run per news push; round-scoped so a news posted in
-- round N only pauses round N. While a row is "live" (now < created_at + pause_seconds) the schedule
-- and the countdown both gain up-to pause_seconds; once elapsed the +pause_seconds is locked in, i.e.
-- the round really was paused for that long.
CREATE TABLE IF NOT EXISTS sim1_news (
  news_id      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id       uuid NOT NULL REFERENCES simulation_runs(run_id) ON DELETE CASCADE,
  round_number int  NOT NULL,
  headline     text NOT NULL,
  body         text NOT NULL DEFAULT '',
  pause_seconds int NOT NULL DEFAULT 25,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_sim1_news_run_round ON sim1_news(run_id, round_number);

-- faculty action log: allow NEWS (broadcast) and TIMEOUT (auto-advance) alongside the existing set.
ALTER TABLE faculty_actions DROP CONSTRAINT IF EXISTS faculty_actions_action_type_check;
ALTER TABLE faculty_actions ADD CONSTRAINT faculty_actions_action_type_check
  CHECK (action_type = ANY (ARRAY[
    'PAUSE','RESUME','DELAY','BYPASS','INJECT','OVERRIDE','TERMINATE','RESTART','NEWS','TIMEOUT'
  ]));

COMMIT;
