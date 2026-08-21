-- Round timing update: R3 = 15 min, R4 = 20 min, R5 = 15 min.
-- Also align each round's artifact expiry offsets to the new window.
DO $$
DECLARE sim uuid := '5116d200-0000-4000-a000-000000000002';
BEGIN
  UPDATE rounds SET duration_minutes = 15 WHERE simulation_id = sim AND round_number = 3;
  UPDATE rounds SET duration_minutes = 20 WHERE simulation_id = sim AND round_number = 4;
  UPDATE rounds SET duration_minutes = 15 WHERE simulation_id = sim AND round_number = 5;

  UPDATE artifacts a SET expiry_offset_min = 15
  FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim AND r.round_number = 3;
  UPDATE artifacts a SET expiry_offset_min = 20
  FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim AND r.round_number = 4;
  UPDATE artifacts a SET expiry_offset_min = 15
  FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim AND r.round_number = 5;
END $$;
