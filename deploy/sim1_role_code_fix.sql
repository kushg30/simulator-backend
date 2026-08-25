-- Sim 1 (ANP Phoenix) role-code fix.
-- Participants are assigned role codes OPERATIONS / PRODUCT (from simulation_roles),
-- but three Round-1 decisions gated on HEAD_OF_OPERATIONS / HEAD_OF_PRODUCT, so those
-- players got "Role not allowed to take this decision". Artifacts already use the
-- correct codes; only decisions.allowed_roles was wrong. Normalize them.
UPDATE decisions d
SET allowed_roles = replace(
                      replace(d.allowed_roles::text, 'HEAD_OF_OPERATIONS', 'OPERATIONS'),
                      'HEAD_OF_PRODUCT', 'PRODUCT'
                    )::jsonb
FROM artifacts a
JOIN rounds r ON r.round_id = a.round_id
WHERE d.artifact_id = a.artifact_id
  AND r.simulation_id = '475db739-0708-48d4-b4db-5a23f1da50d9'
  AND (d.allowed_roles::text LIKE '%HEAD_OF_OPERATIONS%'
       OR d.allowed_roles::text LIKE '%HEAD_OF_PRODUCT%');
