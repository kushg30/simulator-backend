-- Time-boxed rounds: the CEO's round-ending decision opens at the Deliberation-Phase start
-- (feed-phase end) so it can be submitted during the round; the round then advances strictly at
-- its deadline, not on submission. Feed ends R1 T+8, R2 T+8, R3 T+7, R4 T+6.
BEGIN;
UPDATE artifacts a SET open_offset_min = CASE r.round_number WHEN 1 THEN 8 WHEN 2 THEN 8 WHEN 3 THEN 7 WHEN 4 THEN 6 END
FROM rounds r, decisions d
WHERE a.round_id=r.round_id AND d.artifact_id=a.artifact_id AND d.is_final
  AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9';
COMMIT;
