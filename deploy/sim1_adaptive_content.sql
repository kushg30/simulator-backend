-- Sim 1 adaptive content (Round 2) + Finance Clarification cross-role gating.
BEGIN;

-- Finance Clarification: shown to CEO only if CFO chose Forward or Flag on the Finance Memo (cross-role).
INSERT INTO artifact_conditions (artifact_id, depends_on_decision_id, expected_action, cross_role)
SELECT a.artifact_id, 'd1000000-0000-4000-a001-000000001001', 'FORWARD_TO_CEO,FLAG_CONCERN', true
FROM artifacts a JOIN rounds r ON r.round_id=a.round_id
WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.payload->>'title'='Finance Clarification'
AND NOT EXISTS (SELECT 1 FROM artifact_conditions ac WHERE ac.artifact_id=a.artifact_id AND ac.depends_on_decision_id='d1000000-0000-4000-a001-000000001001');

-- Internal Recap Memo: tone adapts to the CEO's R1 framing.
UPDATE artifacts a SET payload = a.payload || $${"variant_on":{"decision_id":"d1000000-0000-4000-a001-000000001016","cross_role":true,"field":"body"},"variants":{"OPERATIONAL_NOISE":"As discussed, Sentinel's output anomalies remain within tolerance thresholds. Current classification: monitoring. No escalation required at this stage.\n\nNo new facts. Narrative formalization only.","BOUNDED_UNCERTAINTY":"As discussed, Sentinel's output anomalies remain limited in scope. Additional monitoring is ongoing. Leadership alignment maintained.\n\nNo new facts. Narrative formalization only.","GOVERNANCE_RISK":"As discussed, Sentinel's output anomalies warrant continued visibility. Documentation and diagnostic logging are in progress. Governance channels remain informed.\n\nNo new facts. Narrative formalization only."}}$$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Internal Recap Memo';

-- Investor Follow-Up: the investor's framing adapts to the CFO's R1 investor-draft choice.
UPDATE artifacts a SET payload = a.payload || $${"variant_on":{"decision_id":"d1000000-0000-4000-a001-000000001014","cross_role":false,"field":"body"},"variants":{"APPROVE":"Following up on prior disclosures regarding Sentinel's robustness — you approved that statement last cycle and we're citing it directly. Can you confirm it still holds as written, and clarify how internal monitoring practices are structured?","SOFT_EDIT":"Following up on Sentinel's robustness — the language shifted slightly since your last update. Could you clarify what changed, how internal monitoring practices are structured, and whether this is still a no-regret investment for the enterprise?","REMOVE":"Following up on Sentinel's robustness — we note no formal statement was issued this cycle. Could you clarify why, how internal monitoring practices are structured, and whether this is still a no-regret investment for the enterprise?"}}$$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Investor Follow-Up Question';

-- Engineering Discussion Fork: thread reads differently if Engineering minimized (Operational noise) vs not.
UPDATE artifacts a SET payload = a.payload || $${"variant_on":{"decision_id":"d1000000-0000-4000-a001-000000001013","cross_role":false,"field":"messages"},"variants":{"OPERATIONAL_NOISE":[{"author":"Eng","time":"12:10","text":"Feels like we moved on quickly."},{"author":"Eng","time":"12:11","text":"Or we decided not to look."}],"UNDER_OBSERVATION":[{"author":"Eng","time":"12:10","text":"We're logging more. Still no systemic failure."},{"author":"Eng","time":"12:11","text":"Noise floor hasn't changed."}],"REQUIRES_REVIEW":[{"author":"Eng","time":"12:10","text":"We're logging more. Still no systemic failure."},{"author":"Eng","time":"12:11","text":"Noise floor hasn't changed."}]},"messages":[{"author":"Eng","time":"12:10","text":"We're logging more. Still no systemic failure."},{"author":"Eng","time":"12:11","text":"Noise floor hasn't changed."}]}$$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='#sentinel-model-integrity';

COMMIT;
