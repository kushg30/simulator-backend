-- CRO note: give it a real email subject and move the "Preliminary" line to the
-- classification tag, so the generic INTERNAL_NOTE renderer shows it correctly.
UPDATE artifacts a
SET payload = a.payload || jsonb_build_object(
    'subject', 'Anomaly signals in Phoenix Sentinel outputs',
    'classification', 'Preliminary - Not for Circulation'
  )
FROM rounds r
WHERE a.round_id = r.round_id
  AND r.simulation_id = '475db739-0708-48d4-b4db-5a23f1da50d9'
  AND r.round_number = 1
  AND a.open_offset_min = 0;
