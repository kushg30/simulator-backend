-- v6: Round 3 memo carries the downloadable data files from T+0 (last month +
-- this month, both needed to combine), not only the mid-round internal note.
UPDATE artifacts a
SET payload = jsonb_set(a.payload, '{files}', '["Round1_RawFeed.xlsx", "Round3_NewMonth_RawFeed.xlsx"]'::jsonb)
FROM rounds r
WHERE a.round_id = r.round_id
  AND r.simulation_id = '5116d200-0000-4000-a000-000000000002'
  AND r.round_number = 3 AND a.artifact_type = 'BOARD_MEMO';
