-- Prevent duplicate submissions for the same round (double-click, or the timeout
-- auto-submit racing a manual submit). One submission per (run, round).
ALTER TABLE sim2_submissions
  ADD CONSTRAINT uq_sim2_submissions_run_round UNIQUE (run_id, round_number);
