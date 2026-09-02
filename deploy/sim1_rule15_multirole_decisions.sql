-- Sim 1 Decision Ownership Rule 1.5: an artifact addressed to more than one role → each addressed
-- role submits its own micro-decision independently. Four ambient "All" artifacts were CEO-only;
-- open them to all six roles. Leadership Alignment Meeting stays CEO-only (script: "CEO submits").
BEGIN;
UPDATE decisions d
SET allowed_roles = '["CEO","CFO","CHRO","HEAD_OF_ENGINEERING","OPERATIONS","PRODUCT"]'::jsonb
FROM artifacts a, rounds r
WHERE d.artifact_id = a.artifact_id AND a.round_id = r.round_id
  AND r.simulation_id = '475db739-0708-48d4-b4db-5a23f1da50d9'
  AND a.allowed_roles IS NULL
  AND d.is_final = false
  AND (a.payload->>'title') IN ('#ai-program', '#leadership', 'Investor Market Commentary', 'Internal Reflection');
COMMIT;
