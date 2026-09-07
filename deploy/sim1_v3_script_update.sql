-- Sim 1 v3: 2026-09-07 script update — relabelled round-ending options, new R2 recap texts,
-- retimed R2 artifacts, short name "Phoenix AI Judgment", and conflict-resolution (most-cautious of
-- two roles) for the investor-tone and engineering-fork branches.
BEGIN;

UPDATE simulations SET name='Phoenix AI Judgment' WHERE simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9';

UPDATE decisions d SET options=$$[{"id":"OPERATIONAL_NOISE","label":"This is a technical monitoring matter — Engineering owns it, no broader leadership framing needed."},{"id":"BOUNDED_UNCERTAINTY","label":"This is a commercial risk to the rollout — leadership owns it as a speed problem, framed around protecting the timeline."},{"id":"GOVERNANCE_RISK","label":"This is a governance matter — leadership owns it as a trust problem, framed around what happens if it's wrong later."}]$$::jsonb
FROM artifacts a JOIN rounds r ON r.round_id=a.round_id
WHERE d.artifact_id=a.artifact_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND d.is_final;
UPDATE decisions d SET options=$$[{"id":"CONTAINED_MATTER","label":"Contained operational matter — hold the language. Nothing has technically changed since Round 1, and re-opening the frame now signals uncertainty we haven't actually confirmed."},{"id":"MONITORING_REPORTING","label":"Structured reporting, no escalation — treat this as a process discipline gap, not a risk finding. Fix how we track it, not what it means."},{"id":"GOVERNANCE_OVERSIGHT","label":"Governance oversight, formal documentation — put it on record now, before external parties raise it for us."}]$$::jsonb
FROM artifacts a JOIN rounds r ON r.round_id=a.round_id
WHERE d.artifact_id=a.artifact_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND d.is_final;
UPDATE decisions d SET options=$$[{"id":"MAINTAIN_MONITORING","label":"Maintain internal monitoring posture — we've had two rounds of stable signal; changing course now would be reacting to attention, not to evidence."},{"id":"FORMALIZE_REPORTING","label":"Formalize reporting without escalation — give the process more rigor without declaring a finding we don't have."},{"id":"ELEVATE_GOVERNANCE","label":"Elevate documentation and board visibility now — the pattern of repeated external questions is itself the signal, even if the underlying anomaly hasn't changed."}]$$::jsonb
FROM artifacts a JOIN rounds r ON r.round_id=a.round_id
WHERE d.artifact_id=a.artifact_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND d.is_final;
UPDATE decisions d SET options=$$[{"id":"PROPORTIONAL_RESPONSE","label":"Call it an appropriate, proportional response — the team read weak signals correctly and didn't over-react to noise. This is what disciplined judgment under ambiguity looks like."},{"id":"FRAGMENTED_ALIGNMENT","label":"Call it fragmented alignment — different functions read the same signals differently, and the team never fully reconciled that. The lesson is process, not judgment."},{"id":"UNDERRECOGNIZED_EXPOSURE","label":"Call it under-recognized governance exposure — the organization had enough signal, across four rounds, to act sooner, and the incentive structure made sure nobody did."}]$$::jsonb
FROM artifacts a JOIN rounds r ON r.round_id=a.round_id
WHERE d.artifact_id=a.artifact_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND d.is_final;

UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{variants}', $${"OPERATIONAL_NOISE":"As discussed, this remains an Engineering monitoring matter. Current classification: technical, contained. No broader escalation required at this stage.\n\nNo new facts. Narrative formalization only.","BOUNDED_UNCERTAINTY":"As discussed, we're treating this as a rollout-protection priority. Diagnostics continue on an accelerated timeline to keep the program on track.\n\nNo new facts. Narrative formalization only.","GOVERNANCE_RISK":"As discussed, Sentinel's output anomalies now carry formal governance visibility. Documentation and diagnostic logging are in progress. Governance channels remain informed.\n\nNo new facts. Narrative formalization only."}$$::jsonb), '{body}', $$"As discussed, we're treating this as a rollout-protection priority. Diagnostics continue on an accelerated timeline to keep the program on track.\n\nNo new facts. Narrative formalization only."$$::jsonb)
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Internal Recap Memo';

UPDATE artifacts a SET open_offset_min=3 FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Model Monitoring Digest';
UPDATE artifacts a SET open_offset_min=6 FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='#sentinel-model-integrity';

UPDATE artifacts a SET payload = jsonb_set(a.payload, '{variant_on,cautious_order}', $$["REMOVE","SOFT_EDIT","APPROVE"]$$::jsonb)
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Investor Follow-Up Question';
UPDATE artifacts a SET payload = jsonb_set(a.payload, '{variant_on,cautious_order}', $$["REQUIRES_REVIEW","UNDER_OBSERVATION","OPERATIONAL_NOISE"]$$::jsonb)
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='#sentinel-model-integrity';

COMMIT;
