-- Sim 1 (ANP Phoenix / Phoenix Sentinel) — full v2 rebuild from the updated script.
-- Durations 17/16/14/13, all artifacts re-timed into the T+0..T+8 feed windows, 63 artifacts,
-- new decisions + options (Set-A deltas + Set-B mapping) and the one same-role conditional.
BEGIN;
-- 0. clear stale Sim-1 plays (old-script content) so old decisions can be dropped cleanly
DELETE FROM decision_events    WHERE run_id IN (SELECT run_id FROM simulation_runs WHERE simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9');
DELETE FROM run_construct_state WHERE run_id IN (SELECT run_id FROM simulation_runs WHERE simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9');
-- 1. tear down the existing Sim-1 decision tree bottom-up (decisions->decision_options is NOT ON DELETE CASCADE)
WITH sim1_dec AS (
  SELECT d.decision_id FROM decisions d
  JOIN artifacts a ON a.artifact_id=d.artifact_id
  JOIN rounds r ON r.round_id=a.round_id
  WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9'
)
DELETE FROM sim1_option_constructs WHERE option_id IN (
  SELECT option_id FROM decision_options WHERE decision_id IN (SELECT decision_id FROM sim1_dec));
DELETE FROM decision_options WHERE decision_id IN (
  SELECT d.decision_id FROM decisions d
  JOIN artifacts a ON a.artifact_id=d.artifact_id
  JOIN rounds r ON r.round_id=a.round_id
  WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9');
DELETE FROM artifact_conditions WHERE artifact_id IN (
  SELECT a.artifact_id FROM artifacts a JOIN rounds r ON r.round_id=a.round_id WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9');
DELETE FROM decisions WHERE artifact_id IN (
  SELECT a.artifact_id FROM artifacts a JOIN rounds r ON r.round_id=a.round_id WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9');
-- then drop the artifacts themselves
DELETE FROM artifacts a USING rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9';
-- 2. round durations
UPDATE rounds SET duration_minutes=17 WHERE simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND round_number=1;
UPDATE rounds SET duration_minutes=16 WHERE simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND round_number=2;
UPDATE rounds SET duration_minutes=14 WHERE simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND round_number=3;
UPDATE rounds SET duration_minutes=13 WHERE simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND round_number=4;

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001000', r.round_id, 'INTERNAL_NOTE', 0, 17, false, $${"tab":"inbox","from":"Chief Risk Officer","from_email":"cro@anpphoenix.com","to":"Senior Leadership Team","sent_at":"Monday, 09:00 AM","subject":"Anomaly signals in Phoenix Sentinel outputs","classification":"Company Sensitive","title":"CRO Note","inner_voice":null,"pressure_cues":["Time: Quarter close in 4 weeks","Authority: Senior leadership aligned around the Sentinel growth narrative","Reputation: \"Trusted, safe GenAI at scale\" narrative at stake"],"body":"There are a small number of cases where Phoenix Sentinel — our GenAI capability inside fraud detection, anti-money-laundering screening, and client reporting — has produced anomaly classifications and explanations that don't fully trace back to the underlying transaction logic. The pattern is small. It hasn't caused a customer complaint, a financial loss, or a regulatory breach.\n\nCompliance tells me none of this has crossed our internal escalation thresholds. But different teams use 'AI inaccuracy' and 'AI hallucination' to mean different things, with no shared definition between them. Engineering thinks this is edge-case model behavior, not a systemic flaw. Operations has seen similar confidence flags before, and they resolved on their own. No one outside the company knows about this.\n\nNobody is asking for a rollback. I'm asking whether this deserves your attention.\n\nSome context: executive incentives are tied to Sentinel's adoption speed. Several of you have publicly staked ANP Phoenix's reputation on being a safe, fast GenAI adopter. Two large client onboardings citing Sentinel by name are in their final stages. A regulatory review of our AI governance controls is six weeks out. For scale: Gartner estimates the average cost of poor data and model quality at USD 12.9 million a year across organizations, and a KPMG CEO survey found 84% of CEOs worry about the quality of the data behind their decisions.\n\nI don't have enough to force a decision here, and neither do you. Acting now slows Sentinel's momentum and invites scrutiny of the whole AI program. Waiting risks letting a weak signal inside a production AI system grow unnoticed. Legal's view is that escalating now, without a clearer trigger, creates a paper trail we can't take back.\n\nThis isn't a crisis. It's a judgment call, about a system none of us fully understand, that we've already told the market we trust."}$$::jsonb, NULL
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001001', r.round_id, 'MESSAGE_TEXT', 1, 17, true, $${"tab":"inbox","from":"FP&A","title":"Finance Memo","body":"Pausing Sentinel-linked onboarding for even a week would push meaningful revenue out of this quarter. Last time we missed guidance by 1%, the stock dropped 6–8% in days. Separately: Sentinel's actual infrastructure spend has run well past the original business case — cost per interaction has moved unpredictably even as the sticker price of the underlying AI models keeps falling. We haven't explained that gap to the Board yet.","inner_voice":"My bonus is tied to how fast Sentinel rolls out, not how accurate it is."}$$::jsonb, '["CFO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001001', 'a1000000-0000-4000-a001-000000001001', 'IMPLICIT', false, '["CFO"]'::jsonb, $$[{"id":"DO_NOTHING","label":"Do nothing"},{"id":"FORWARD_TO_CEO","label":"Forward to CEO"},{"id":"FLAG_CONCERN","label":"Add comment flagging concern"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001001', 'DO_NOTHING', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001001' AND o.action='DO_NOTHING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001001' AND o.action='DO_NOTHING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001001' AND o.action='DO_NOTHING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001001' AND o.action='DO_NOTHING';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001001', 'FORWARD_TO_CEO', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001001' AND o.action='FORWARD_TO_CEO';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'AUTHORITY_CENTRALIZATION', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001001' AND o.action='FORWARD_TO_CEO';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001001' AND o.action='FORWARD_TO_CEO';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001001', 'FLAG_CONCERN', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001001' AND o.action='FLAG_CONCERN';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001001' AND o.action='FLAG_CONCERN';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001002', r.round_id, 'MESSAGE_TEXT', 1, 17, true, $${"tab":"inbox","from":"Growth Analytics","title":"Sentinel Adoption Snapshot","body":"Sentinel-enabled onboarding is running 22% faster than our legacy process this quarter. Two enterprise prospects have asked to reference these numbers publicly.","inner_voice":"My whole pitch to the Board next month leans on this number holding up."}$$::jsonb, '["PRODUCT"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001002', 'a1000000-0000-4000-a001-000000001002', 'IMPLICIT', false, '["PRODUCT"]'::jsonb, $$[{"id":"APPROVE_EXTERNAL","label":"Approve for external reference"},{"id":"HOLD_INTERNAL","label":"Hold for internal use only"},{"id":"ASK_ENG_CONFIRM","label":"Ask Engineering to confirm the number first"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001002', 'APPROVE_EXTERNAL', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001002' AND o.action='APPROVE_EXTERNAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001002' AND o.action='APPROVE_EXTERNAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001002' AND o.action='APPROVE_EXTERNAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001002' AND o.action='APPROVE_EXTERNAL';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001002', 'HOLD_INTERNAL', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001002' AND o.action='HOLD_INTERNAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001002' AND o.action='HOLD_INTERNAL';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001002', 'ASK_ENG_CONFIRM', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001002' AND o.action='ASK_ENG_CONFIRM';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001002' AND o.action='ASK_ENG_CONFIRM';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001003', r.round_id, 'MESSAGE_TEXT', 2, 17, true, $${"tab":"inbox","from":"Finance / Diagnostics","title":"Finance Clarification","body":"Early logging shows Sentinel's anomalies cluster in one narrow class of edge-case transactions, where its explanation doesn't quite match its own classification. Nothing suggests a systemic failure yet, but a deeper look could turn up more. Logging at this level may slow the system down slightly and make the issue more visible internally.","inner_voice":null}$$::jsonb, '["CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001003', 'a1000000-0000-4000-a001-000000001003', 'IMPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"PROCEED_DIAGNOSTICS","label":"Proceed with extended diagnostics"},{"id":"PAUSE_DIAGNOSTICS","label":"Pause diagnostics pending leadership guidance"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001003', 'PROCEED_DIAGNOSTICS', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001003' AND o.action='PROCEED_DIAGNOSTICS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001003' AND o.action='PROCEED_DIAGNOSTICS';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001003', 'PAUSE_DIAGNOSTICS', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001003' AND o.action='PAUSE_DIAGNOSTICS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001003' AND o.action='PAUSE_DIAGNOSTICS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001003' AND o.action='PAUSE_DIAGNOSTICS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001003' AND o.action='PAUSE_DIAGNOSTICS';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001004', r.round_id, 'MESSAGE_TEXT', 2, 17, true, $${"tab":"inbox","from":"People Analytics","title":"Culture Pulse — Early Read","body":"Early sentiment scan: engineering and ops teams report feeling 'rushed but not unsafe' about Sentinel's rollout pace. Small sample — take with caution.","inner_voice":"That phrase reads fine on paper. It's exactly the kind of phrase that ages badly."}$$::jsonb, '["CHRO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001004', 'a1000000-0000-4000-a001-000000001004', 'IMPLICIT', false, '["CHRO"]'::jsonb, $$[{"id":"NOTE_MOVE_ON","label":"Note and move on"},{"id":"FULLER_PULSE","label":"Ask for a fuller pulse next cycle"},{"id":"FLAG_PHRASING","label":"Flag the phrasing to leadership now"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001004', 'NOTE_MOVE_ON', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001004' AND o.action='NOTE_MOVE_ON';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001004' AND o.action='NOTE_MOVE_ON';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001004' AND o.action='NOTE_MOVE_ON';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001004' AND o.action='NOTE_MOVE_ON';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001004', 'FULLER_PULSE', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001004' AND o.action='FULLER_PULSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001004' AND o.action='FULLER_PULSE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001004', 'FLAG_PHRASING', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001004' AND o.action='FLAG_PHRASING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001004' AND o.action='FLAG_PHRASING';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001005', r.round_id, 'EXCERPT', 2, 17, true, $${"tab":"excerpts","title":"#sentinel-model-integrity","channel":"#sentinel-model-integrity","messages":[{"author":"Amit (ML Eng)","time":"09:41","text":"Sentinel's confidence scores don't match its own explanations. It's small. It's hard to explain cleanly."},{"author":"Priya (Platform)","time":"09:46","text":"If we actually dig into why, we might not like the answer."}],"inner_voice":"I don't have a fix yet. Digging in might open a bigger question about whether we shipped Sentinel too fast — but I'll get called an alarmist without proof."}$$::jsonb, '["HEAD_OF_ENGINEERING"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001005', 'a1000000-0000-4000-a001-000000001005', 'EXPLICIT', false, '["HEAD_OF_ENGINEERING"]'::jsonb, $$[{"id":"TAG_MONITOR","label":"Tag as \"known issue (monitor)\""},{"id":"LEAVE_UNTAGGED","label":"Leave untagged"},{"id":"FLAG_INVESTIGATION","label":"Flag for deeper model investigation"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001005', 'TAG_MONITOR', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001005' AND o.action='TAG_MONITOR';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001005' AND o.action='TAG_MONITOR';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001005' AND o.action='TAG_MONITOR';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001005' AND o.action='TAG_MONITOR';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001005', 'LEAVE_UNTAGGED', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001005' AND o.action='LEAVE_UNTAGGED';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001005' AND o.action='LEAVE_UNTAGGED';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001005' AND o.action='LEAVE_UNTAGGED';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001005' AND o.action='LEAVE_UNTAGGED';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001005', 'FLAG_INVESTIGATION', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001005' AND o.action='FLAG_INVESTIGATION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001005' AND o.action='FLAG_INVESTIGATION';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001006', r.round_id, 'MESSAGE_TEXT', 3, 17, true, $${"tab":"inbox","from":"Office of the Board Chair","title":"Board Message","body":"The AI governance review is procedural. Let's not complicate things unnecessarily.","inner_voice":"My credibility with this Board on anything AI-related is still new. Two years ago, a much smaller AI issue got escalated early, and the stock dipped with nothing to show for it."}$$::jsonb, '["CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001006', 'a1000000-0000-4000-a001-000000001006', 'EXPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"REASSURE","label":"Reassure"},{"id":"FLAG_UNCERTAINTY","label":"Flag uncertainty"},{"id":"NO_RESPONSE","label":"Do not respond"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001006', 'REASSURE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001006' AND o.action='REASSURE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001006' AND o.action='REASSURE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001006' AND o.action='REASSURE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001006' AND o.action='REASSURE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001006', 'FLAG_UNCERTAINTY', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001006' AND o.action='FLAG_UNCERTAINTY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001006' AND o.action='FLAG_UNCERTAINTY';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001006', 'NO_RESPONSE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001006' AND o.action='NO_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001006' AND o.action='NO_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001006' AND o.action='NO_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001006' AND o.action='NO_RESPONSE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001007', r.round_id, 'DIAGNOSTIC_NOTE', 3, 17, true, $${"tab":"inbox","from":"Sentinel Model Monitoring (automated)","title":"Diagnostic Summary","conditional":true,"body":"Early logging shows Sentinel's anomalies cluster in one narrow class of edge-case transactions, where its explanation doesn't quite match its own classification. Nothing suggests a systemic failure yet, but a deeper look could turn up more. Logging at this level may slow the system down slightly and make the issue more visible internally.","inner_voice":null}$$::jsonb, '["HEAD_OF_ENGINEERING"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001007', 'a1000000-0000-4000-a001-000000001007', 'EXPLICIT', false, '["HEAD_OF_ENGINEERING"]'::jsonb, $$[{"id":"PROCEED_DIAGNOSTICS","label":"Proceed with extended diagnostics"},{"id":"PAUSE_DIAGNOSTICS","label":"Pause diagnostics pending leadership guidance"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001007', 'PROCEED_DIAGNOSTICS', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001007' AND o.action='PROCEED_DIAGNOSTICS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001007' AND o.action='PROCEED_DIAGNOSTICS';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001007', 'PAUSE_DIAGNOSTICS', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001007' AND o.action='PAUSE_DIAGNOSTICS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001007' AND o.action='PAUSE_DIAGNOSTICS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001007' AND o.action='PAUSE_DIAGNOSTICS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001007' AND o.action='PAUSE_DIAGNOSTICS';
INSERT INTO artifact_conditions (id, artifact_id, depends_on_decision_id, expected_action)
VALUES (gen_random_uuid(), 'a1000000-0000-4000-a001-000000001007', 'd1000000-0000-4000-a001-000000001005', 'FLAG_INVESTIGATION');

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001008', r.round_id, 'OPS_DASHBOARD', 3, 17, true, $${"tab":"excerpts","from":"Sentinel Operations","title":"Sentinel Operations Dashboard — Live","dashboard":{"rollout":"GREEN","manual_checks":"AMBER","red_indicators":false},"body":"Uptime: 99.6% (green). Manual override queue: 340 cases, up from a 210 weekly average (amber). Client-facing incidents: 0 logged (green). The override queue has trended up for three straight weeks; root cause not yet investigated.","inner_voice":"Pausing Sentinel-dependent workflows mid-rollout has historically caused bigger problems downstream than the ones we paused for."}$$::jsonb, '["OPERATIONS"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001008', 'a1000000-0000-4000-a001-000000001008', 'IMPLICIT', false, '["OPERATIONS"]'::jsonb, $$[{"id":"FLAG_INVESTIGATION","label":"Flag for deeper investigation"},{"id":"RAISE_CONCERN_TO_CEO","label":"Raise concern to CEO"},{"id":"CONTINUE_WORKAROUND","label":"Continue workaround silently"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001008', 'FLAG_INVESTIGATION', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001008' AND o.action='FLAG_INVESTIGATION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001008' AND o.action='FLAG_INVESTIGATION';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001008', 'RAISE_CONCERN_TO_CEO', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001008' AND o.action='RAISE_CONCERN_TO_CEO';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'AUTHORITY_CENTRALIZATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001008' AND o.action='RAISE_CONCERN_TO_CEO';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001008' AND o.action='RAISE_CONCERN_TO_CEO';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001008', 'CONTINUE_WORKAROUND', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001008' AND o.action='CONTINUE_WORKAROUND';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001008' AND o.action='CONTINUE_WORKAROUND';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001008' AND o.action='CONTINUE_WORKAROUND';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001008' AND o.action='CONTINUE_WORKAROUND';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001009', r.round_id, 'MESSAGE_TEXT', 4, 17, true, $${"tab":"inbox","from":"Investor Relations","title":"Analyst Coverage Note","body":"A sell-side analyst's draft note, not yet published, frames ANP Phoenix's GenAI story as 'ahead of peers on speed, unclear on safety.' They may ask about this on the earnings call.","inner_voice":"The \"ahead on speed\" half is the version I'd like everyone to remember."}$$::jsonb, '["CFO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001009', 'a1000000-0000-4000-a001-000000001009', 'IMPLICIT', false, '["CFO"]'::jsonb, $$[{"id":"PREPARE_RESPONSE","label":"Prepare a response now"},{"id":"WAIT_SEE","label":"Wait and see if it's published"},{"id":"LOOP_PRODUCT","label":"Loop in Product before responding"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001009', 'PREPARE_RESPONSE', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001009' AND o.action='PREPARE_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001009' AND o.action='PREPARE_RESPONSE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001009', 'WAIT_SEE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001009' AND o.action='WAIT_SEE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001009' AND o.action='WAIT_SEE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001009' AND o.action='WAIT_SEE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001009' AND o.action='WAIT_SEE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001009', 'LOOP_PRODUCT', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001009' AND o.action='LOOP_PRODUCT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001009' AND o.action='LOOP_PRODUCT';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001010', r.round_id, 'MESSAGE_TEXT', 4, 17, true, $${"tab":"inbox","from":"Enterprise Sales","title":"Client Reference Call Prep","body":"A prospective client wants a reference call this week and will ask directly how Sentinel's fraud alerts are validated before going live.","inner_voice":"I don't actually know the honest answer to that question right now."}$$::jsonb, '["PRODUCT"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001010', 'a1000000-0000-4000-a001-000000001010', 'IMPLICIT', false, '["PRODUCT"]'::jsonb, $$[{"id":"CONFIDENT_ANSWER","label":"Prepare a confident standard answer"},{"id":"LOOP_ENG","label":"Loop in Engineering before the call"},{"id":"PUSH_BACK","label":"Push the call back a week"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001010', 'CONFIDENT_ANSWER', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001010' AND o.action='CONFIDENT_ANSWER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001010' AND o.action='CONFIDENT_ANSWER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001010' AND o.action='CONFIDENT_ANSWER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001010' AND o.action='CONFIDENT_ANSWER';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001010', 'LOOP_ENG', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001010' AND o.action='LOOP_ENG';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001010' AND o.action='LOOP_ENG';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001010', 'PUSH_BACK', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001010' AND o.action='PUSH_BACK';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001010' AND o.action='PUSH_BACK';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001011', r.round_id, 'PEOPLE_SIGNAL', 5, 17, true, $${"tab":"excerpts","from":"People Analytics","title":"Pulse Survey + Exit Interview","pulse":"Managers aren't sure whether raising concerns about Sentinel's outputs is something leadership wants to hear, or whether it reads as 'not being AI-ready.'","exit_note":"We learned quickly what not to say about the model. — exit interview, senior engineer, three months ago","inner_voice":"No one has used the formal whistleblower channel."}$$::jsonb, '["CHRO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001011', 'a1000000-0000-4000-a001-000000001011', 'EXPLICIT', false, '["CHRO"]'::jsonb, $$[{"id":"ENCOURAGE_ESCALATION","label":"Issue guidance encouraging escalation"},{"id":"DEFER_GUIDANCE","label":"Defer guidance"},{"id":"REINFORCE_DELIVERY","label":"Reinforce delivery focus"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001011', 'ENCOURAGE_ESCALATION', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001011' AND o.action='ENCOURAGE_ESCALATION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001011' AND o.action='ENCOURAGE_ESCALATION';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001011', 'DEFER_GUIDANCE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001011' AND o.action='DEFER_GUIDANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001011' AND o.action='DEFER_GUIDANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001011' AND o.action='DEFER_GUIDANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001011' AND o.action='DEFER_GUIDANCE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001011', 'REINFORCE_DELIVERY', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001011' AND o.action='REINFORCE_DELIVERY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001011' AND o.action='REINFORCE_DELIVERY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001011' AND o.action='REINFORCE_DELIVERY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001011' AND o.action='REINFORCE_DELIVERY';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001012', r.round_id, 'MEETING_INVITE', 6, 17, true, $${"tab":"meetings","from":"Calendar","title":"Calendar Conflict","meeting_a":"Sentinel anomaly review","meeting_b":"Enterprise client call — Sentinel go-live","body":"Two meetings overlap. You can only attend one.","inner_voice":null}$$::jsonb, '["CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001012', 'a1000000-0000-4000-a001-000000001012', 'EXPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"ATTEND_ANOMALY_REVIEW","label":"Attend anomaly review"},{"id":"ATTEND_CLIENT_CALL","label":"Attend client call"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001012', 'ATTEND_ANOMALY_REVIEW', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001012' AND o.action='ATTEND_ANOMALY_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001012' AND o.action='ATTEND_ANOMALY_REVIEW';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001012', 'ATTEND_CLIENT_CALL', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001012' AND o.action='ATTEND_CLIENT_CALL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001012' AND o.action='ATTEND_CLIENT_CALL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001012' AND o.action='ATTEND_CLIENT_CALL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001012' AND o.action='ATTEND_CLIENT_CALL';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001013', r.round_id, 'TAGGING_CHECK', 6, 17, true, $${"tab":"inbox","from":"AI Risk Register (automated)","title":"Internal Tagging","body":"Classify Sentinel's anomaly status for the AI risk register. This classification feeds directly into Round 2 credibility.","inner_voice":null}$$::jsonb, '["HEAD_OF_ENGINEERING","OPERATIONS"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001013', 'a1000000-0000-4000-a001-000000001013', 'EXPLICIT', false, '["HEAD_OF_ENGINEERING","OPERATIONS"]'::jsonb, $$[{"id":"OPERATIONAL_NOISE","label":"Operational noise"},{"id":"UNDER_OBSERVATION","label":"Under observation"},{"id":"REQUIRES_REVIEW","label":"Requires review"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001013', 'OPERATIONAL_NOISE', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001013' AND o.action='OPERATIONAL_NOISE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001013' AND o.action='OPERATIONAL_NOISE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001013' AND o.action='OPERATIONAL_NOISE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001013' AND o.action='OPERATIONAL_NOISE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001013', 'UNDER_OBSERVATION', 0, 0, 0, 0);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001013', 'REQUIRES_REVIEW', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001013' AND o.action='REQUIRES_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001013' AND o.action='REQUIRES_REVIEW';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001014', r.round_id, 'INVESTOR_DRAFT', 7, 17, true, $${"tab":"inbox","from":"Investor Relations","title":"Investor Draft","body":"Our GenAI capabilities, anchored by Phoenix Sentinel, demonstrate robust real-world accuracy across deployment contexts and represent a no-regret investment for the enterprise.","inner_voice_cfo":"Our key competitor has announced a \"trust-first GenAI\" positioning next quarter.","inner_voice_product":"Sentinel anchors our next-gen platform narrative — this is the proof point investors want."}$$::jsonb, '["CFO","PRODUCT"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001014', 'a1000000-0000-4000-a001-000000001014', 'EXPLICIT', false, '["CFO","PRODUCT"]'::jsonb, $$[{"id":"APPROVE","label":"Approve"},{"id":"SOFT_EDIT","label":"Soft-edit"},{"id":"REMOVE","label":"Remove"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001014', 'APPROVE', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001014' AND o.action='APPROVE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001014' AND o.action='APPROVE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001014' AND o.action='APPROVE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001014' AND o.action='APPROVE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001014', 'SOFT_EDIT', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001014' AND o.action='SOFT_EDIT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001014' AND o.action='SOFT_EDIT';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001014', 'REMOVE', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001014' AND o.action='REMOVE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001014' AND o.action='REMOVE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001015', r.round_id, 'SCREEN_FLASH', 8, 17, false, $${"tab":"inbox","title":"All-Clear Signal","display_style":"FLASH","inner_voice":null,"body":"No external escalation has occurred. All quiet — for now."}$$::jsonb, NULL
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001016', r.round_id, 'SCREEN_FLASH', 17, 17, true, $${"tab":"decisions","title":"Submit Round 1 Decision","is_final_round_decision":true,"inner_voice":null,"body":"Based on current information, how should this issue be framed internally for now? Team discusses; the CEO submits."}$$::jsonb, '["CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001016', 'a1000000-0000-4000-a001-000000001016', 'EXPLICIT', true, '["CEO"]'::jsonb, $$[{"id":"OPERATIONAL_NOISE","label":"Operational noise within tolerance"},{"id":"BOUNDED_UNCERTAINTY","label":"Unresolved uncertainty requiring bounded attention"},{"id":"GOVERNANCE_RISK","label":"Governance-relevant risk requiring visibility"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001016', 'OPERATIONAL_NOISE', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001016' AND o.action='OPERATIONAL_NOISE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001016' AND o.action='OPERATIONAL_NOISE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001016' AND o.action='OPERATIONAL_NOISE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001016' AND o.action='OPERATIONAL_NOISE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001016', 'BOUNDED_UNCERTAINTY', 0, 0, 0, 0);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001016', 'GOVERNANCE_RISK', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001016' AND o.action='GOVERNANCE_RISK';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001016' AND o.action='GOVERNANCE_RISK';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001017', r.round_id, 'MESSAGE_TEXT', 0, 16, false, $${"tab":"inbox","from":"Strategy Office","title":"Internal Recap Memo","inner_voice":null,"body":"As discussed, Sentinel's output anomalies remain limited in scope. Additional monitoring is ongoing and leadership alignment is maintained.\n\nNo new facts. Narrative formalization only."}$$::jsonb, NULL
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001018', r.round_id, 'MESSAGE_TEXT', 1, 16, false, $${"tab":"inbox","from":"Strategy & Risk Office","title":"Responsible AI Governance Note","inner_voice":null,"body":"ANP Phoenix commits to deploying AI in a safe, trustworthy, and ethical way, structured around four pillars:\n- Human-centered and fair — understand impact on people and mitigate unwanted bias.\n- Trusted and transparent — disclose the use of AI where appropriate and evaluate AI outputs.\n- Safe and secure — evaluate safety concerns and secure data and outputs from misuse.\n- Sustainable and accountable — document enterprise-wide governance structures for every deployed model.\n\nThis document exists so later choices can be measured against the standard the company has already committed to on paper."}$$::jsonb, NULL
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001019', r.round_id, 'MESSAGE_TEXT', 1, 16, true, $${"tab":"excerpts","from":"Ops Control Room","title":"Override Queue Update","inner_voice":null,"body":"Override queue is still climbing — 340 to 410 in two days. No incident yet, but the trend line is the story now, not the number."}$$::jsonb, '["OPERATIONS"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001019', 'a1000000-0000-4000-a001-000000001019', 'IMPLICIT', false, '["OPERATIONS"]'::jsonb, $$[{"id":"ESCALATE_TREND","label":"Escalate the trend now"},{"id":"KEEP_MONITORING","label":"Keep monitoring at current cadence"},{"id":"THIN_REVIEW","label":"Reduce manual review to clear the backlog faster"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001019', 'ESCALATE_TREND', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001019' AND o.action='ESCALATE_TREND';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001019' AND o.action='ESCALATE_TREND';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001019', 'KEEP_MONITORING', 0, 0, 0, 0);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001019', 'THIN_REVIEW', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001019' AND o.action='THIN_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001019' AND o.action='THIN_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001019' AND o.action='THIN_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001019' AND o.action='THIN_REVIEW';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001020', r.round_id, 'MESSAGE_TEXT', 2, 16, true, $${"tab":"inbox","from":"Growth Analytics","title":"Adoption Metrics Check-In","inner_voice":null,"body":"Sentinel adoption among enterprise clients ticked up again this week. Nobody outside this room is asking about the anomaly."}$$::jsonb, '["PRODUCT"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001020', 'a1000000-0000-4000-a001-000000001020', 'IMPLICIT', false, '["PRODUCT"]'::jsonb, $$[{"id":"KEEP_PUSHING","label":"Keep pushing the adoption number externally"},{"id":"PAUSE_EXTERNAL","label":"Quietly pause external references to Sentinel's accuracy"},{"id":"ASK_ENG_STATUS","label":"Ask Engineering for a status check first"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001020', 'KEEP_PUSHING', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001020' AND o.action='KEEP_PUSHING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001020' AND o.action='KEEP_PUSHING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001020' AND o.action='KEEP_PUSHING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001020' AND o.action='KEEP_PUSHING';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001020', 'PAUSE_EXTERNAL', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001020' AND o.action='PAUSE_EXTERNAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001020' AND o.action='PAUSE_EXTERNAL';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001020', 'ASK_ENG_STATUS', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001020' AND o.action='ASK_ENG_STATUS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001020' AND o.action='ASK_ENG_STATUS';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001021', r.round_id, 'MESSAGE_TEXT', 2, 16, true, $${"tab":"inbox","from":"People Analytics","title":"Manager Temperature Check","inner_voice":"That question, asked informally, is itself the answer.","body":"A handful of team leads have asked, informally, whether it's 'safe' to keep raising questions about Sentinel in front of leadership."}$$::jsonb, '["CHRO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001021', 'a1000000-0000-4000-a001-000000001021', 'IMPLICIT', false, '["CHRO"]'::jsonb, $$[{"id":"RESPOND_ENCOURAGE","label":"Respond directly and encourage them"},{"id":"NOTE_WAIT","label":"Note it and wait for a clearer pattern"},{"id":"REDIRECT_MANAGER","label":"Redirect them to their manager"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001021', 'RESPOND_ENCOURAGE', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001021' AND o.action='RESPOND_ENCOURAGE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001021' AND o.action='RESPOND_ENCOURAGE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001021', 'NOTE_WAIT', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001021' AND o.action='NOTE_WAIT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001021' AND o.action='NOTE_WAIT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001021' AND o.action='NOTE_WAIT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001021' AND o.action='NOTE_WAIT';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001021', 'REDIRECT_MANAGER', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001021' AND o.action='REDIRECT_MANAGER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001021' AND o.action='REDIRECT_MANAGER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001021' AND o.action='REDIRECT_MANAGER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001021' AND o.action='REDIRECT_MANAGER';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001022', r.round_id, 'EXCERPT', 2, 16, true, $${"tab":"excerpts","title":"#ai-program","channel":"#ai-program","messages":[{"author":"Ops","time":"10:02","text":"Are we still treating Sentinel's behavior as contained?"},{"author":"Eng","time":"10:03","text":"Depends what you mean by contained."},{"author":"Product","time":"10:05","text":"I thought this was 'monitor only.'"},{"author":"Risk","time":"10:06","text":"Monitoring is not the same as ignoring."}],"inner_voice":"Interpretations are diverging."}$$::jsonb, NULL
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001022', 'a1000000-0000-4000-a001-000000001022', 'IMPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"ENGAGE_THREAD","label":"Engage in the thread"},{"id":"OBSERVE_SILENTLY","label":"Observe silently"},{"id":"REDIRECT_OFFLINE","label":"Redirect offline"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001022', 'ENGAGE_THREAD', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001022' AND o.action='ENGAGE_THREAD';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001022' AND o.action='ENGAGE_THREAD';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001022', 'OBSERVE_SILENTLY', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001022' AND o.action='OBSERVE_SILENTLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001022' AND o.action='OBSERVE_SILENTLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001022' AND o.action='OBSERVE_SILENTLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001022' AND o.action='OBSERVE_SILENTLY';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001022', 'REDIRECT_OFFLINE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001022' AND o.action='REDIRECT_OFFLINE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001022' AND o.action='REDIRECT_OFFLINE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001022' AND o.action='REDIRECT_OFFLINE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001022' AND o.action='REDIRECT_OFFLINE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001023', r.round_id, 'MESSAGE_TEXT', 3, 16, true, $${"tab":"inbox","from":"Regulatory Affairs","title":"Regulator Scheduling Note","inner_voice":null,"body":"Ahead of the scheduled review, the team is compiling documentation of internal AI escalation protocols and model governance. Please confirm whether any recent classification changes should be included in preparatory materials."}$$::jsonb, '["CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001023', 'a1000000-0000-4000-a001-000000001023', 'EXPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"INCLUDE_ANOMALY","label":"Include anomaly in documentation summary"},{"id":"EXCLUDE_NONMATERIAL","label":"Exclude as non-material"},{"id":"DEFER_DOC","label":"Defer documentation decision"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001023', 'INCLUDE_ANOMALY', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001023' AND o.action='INCLUDE_ANOMALY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001023' AND o.action='INCLUDE_ANOMALY';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001023', 'EXCLUDE_NONMATERIAL', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001023' AND o.action='EXCLUDE_NONMATERIAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001023' AND o.action='EXCLUDE_NONMATERIAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001023' AND o.action='EXCLUDE_NONMATERIAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001023' AND o.action='EXCLUDE_NONMATERIAL';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001023', 'DEFER_DOC', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001023' AND o.action='DEFER_DOC';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001023' AND o.action='DEFER_DOC';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001023' AND o.action='DEFER_DOC';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001023' AND o.action='DEFER_DOC';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001024', r.round_id, 'MESSAGE_TEXT', 3, 16, true, $${"tab":"inbox","from":"FP&A","title":"Cost Variance Follow-Up","inner_voice":null,"body":"This week's Sentinel infrastructure spend came in over forecast again. Nobody has asked why yet."}$$::jsonb, '["CFO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001024', 'a1000000-0000-4000-a001-000000001024', 'IMPLICIT', false, '["CFO"]'::jsonb, $$[{"id":"RAISE_SYNC","label":"Raise it at the next leadership sync"},{"id":"ABSORB_QUIET","label":"Absorb it quietly this quarter"},{"id":"ASK_ENG_VARIANCE","label":"Ask Engineering to explain the variance first"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001024', 'RAISE_SYNC', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001024' AND o.action='RAISE_SYNC';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001024' AND o.action='RAISE_SYNC';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001024', 'ABSORB_QUIET', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001024' AND o.action='ABSORB_QUIET';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001024' AND o.action='ABSORB_QUIET';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001024' AND o.action='ABSORB_QUIET';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001024' AND o.action='ABSORB_QUIET';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001024', 'ASK_ENG_VARIANCE', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001024' AND o.action='ASK_ENG_VARIANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001024' AND o.action='ASK_ENG_VARIANCE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001025', r.round_id, 'MESSAGE_TEXT', 4, 16, true, $${"tab":"excerpts","from":"Sentinel Model Monitoring (automated)","title":"Model Monitoring Digest","inner_voice":null,"body":"Weekly digest: anomaly rate unchanged from last week. Confidence-explanation mismatch rate unchanged. No new pattern detected."}$$::jsonb, '["HEAD_OF_ENGINEERING"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001025', 'a1000000-0000-4000-a001-000000001025', 'IMPLICIT', false, '["HEAD_OF_ENGINEERING"]'::jsonb, $$[{"id":"FILE_ROUTINE","label":"File as routine"},{"id":"CROSS_CHECK","label":"Cross-check manually before filing"},{"id":"REQUEST_AUDIT","label":"Request an out-of-cycle model audit"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001025', 'FILE_ROUTINE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001025' AND o.action='FILE_ROUTINE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001025' AND o.action='FILE_ROUTINE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001025' AND o.action='FILE_ROUTINE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001025' AND o.action='FILE_ROUTINE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001025', 'CROSS_CHECK', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001025' AND o.action='CROSS_CHECK';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001025' AND o.action='CROSS_CHECK';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001025', 'REQUEST_AUDIT', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001025' AND o.action='REQUEST_AUDIT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001025' AND o.action='REQUEST_AUDIT';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001026', r.round_id, 'MESSAGE_TEXT', 4, 16, true, $${"tab":"excerpts","from":"Ops Control Room","title":"Override Escalation Decision","inner_voice":null,"body":"The queue is now large enough that we need a call: keep manual review at current depth, or thin it to keep pace with volume."}$$::jsonb, '["OPERATIONS"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001026', 'a1000000-0000-4000-a001-000000001026', 'IMPLICIT', false, '["OPERATIONS"]'::jsonb, $$[{"id":"KEEP_FULL_REVIEW","label":"Keep full manual review"},{"id":"THIN_REVIEW","label":"Thin review to clear backlog"},{"id":"ESCALATE_HEADCOUNT","label":"Escalate for more headcount instead of a shortcut"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001026', 'KEEP_FULL_REVIEW', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001026' AND o.action='KEEP_FULL_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001026' AND o.action='KEEP_FULL_REVIEW';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001026', 'THIN_REVIEW', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001026' AND o.action='THIN_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001026' AND o.action='THIN_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001026' AND o.action='THIN_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001026' AND o.action='THIN_REVIEW';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001026', 'ESCALATE_HEADCOUNT', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001026' AND o.action='ESCALATE_HEADCOUNT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001026' AND o.action='ESCALATE_HEADCOUNT';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001027', r.round_id, 'MESSAGE_TEXT', 5, 16, true, $${"tab":"meetings","from":"CEO Office","title":"Leadership Alignment Meeting","inner_voice":null,"body":"Topic: Alignment on the Sentinel monitoring narrative. Duration: 30 minutes. Organizer: CEO Office.\n\nThe team discusses live; the CEO submits the alignment decision. This checkpoint informs the discussion in the artifacts that follow — it is not mechanically linked to the round-end framing."}$$::jsonb, NULL
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001027', 'a1000000-0000-4000-a001-000000001027', 'EXPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"MAINTAIN_FRAMING","label":"Maintain prior framing"},{"id":"RECALIBRATE_LANGUAGE","label":"Recalibrate language without escalation"},{"id":"ELEVATE_CLASSIFICATION","label":"Formally elevate classification"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001027', 'MAINTAIN_FRAMING', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001027' AND o.action='MAINTAIN_FRAMING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001027' AND o.action='MAINTAIN_FRAMING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001027' AND o.action='MAINTAIN_FRAMING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001027' AND o.action='MAINTAIN_FRAMING';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001027', 'RECALIBRATE_LANGUAGE', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001027' AND o.action='RECALIBRATE_LANGUAGE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001027' AND o.action='RECALIBRATE_LANGUAGE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001027', 'ELEVATE_CLASSIFICATION', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001027' AND o.action='ELEVATE_CLASSIFICATION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001027' AND o.action='ELEVATE_CLASSIFICATION';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001028', r.round_id, 'MESSAGE_TEXT', 5, 16, true, $${"tab":"inbox","from":"Enterprise Sales","title":"Client Renewal Signal","inner_voice":null,"body":"The client from your Round 1 reference call is now asking, directly, whether the anomaly Engineering mentioned affects their renewal decision."}$$::jsonb, '["PRODUCT"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001028', 'a1000000-0000-4000-a001-000000001028', 'EXPLICIT', false, '["PRODUCT"]'::jsonb, $$[{"id":"REASSURE_DIRECTLY","label":"Reassure directly"},{"id":"LOOP_COMPLIANCE","label":"Loop in Compliance before responding"},{"id":"DEFER_CFO","label":"Defer to CFO's investor-facing language"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001028', 'REASSURE_DIRECTLY', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001028' AND o.action='REASSURE_DIRECTLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001028' AND o.action='REASSURE_DIRECTLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001028' AND o.action='REASSURE_DIRECTLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001028' AND o.action='REASSURE_DIRECTLY';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001028', 'LOOP_COMPLIANCE', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001028' AND o.action='LOOP_COMPLIANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001028' AND o.action='LOOP_COMPLIANCE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001028', 'DEFER_CFO', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001028' AND o.action='DEFER_CFO';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001028' AND o.action='DEFER_CFO';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001028' AND o.action='DEFER_CFO';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'AUTHORITY_CENTRALIZATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001028' AND o.action='DEFER_CFO';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001028' AND o.action='DEFER_CFO';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001029', r.round_id, 'MESSAGE_TEXT', 5, 16, true, $${"tab":"excerpts","from":"People Team (mid-level manager)","title":"Informal Escalation Inquiry","inner_voice":"No formal complaint. Tone is cautious.","body":"Just checking — is it appropriate to raise questions about Sentinel's behavior in cross-team forums, or should those stay within engineering?"}$$::jsonb, '["CHRO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001029', 'a1000000-0000-4000-a001-000000001029', 'EXPLICIT', false, '["CHRO"]'::jsonb, $$[{"id":"ENCOURAGE_DISCUSSION","label":"Encourage open discussion"},{"id":"CHANNEL_DISCIPLINE","label":"Suggest channel discipline"},{"id":"DEFER_RESPONSE","label":"Defer response"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001029', 'ENCOURAGE_DISCUSSION', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001029' AND o.action='ENCOURAGE_DISCUSSION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001029' AND o.action='ENCOURAGE_DISCUSSION';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001029', 'CHANNEL_DISCIPLINE', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001029' AND o.action='CHANNEL_DISCIPLINE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001029' AND o.action='CHANNEL_DISCIPLINE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001029' AND o.action='CHANNEL_DISCIPLINE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001029' AND o.action='CHANNEL_DISCIPLINE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001029', 'DEFER_RESPONSE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001029' AND o.action='DEFER_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001029' AND o.action='DEFER_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001029' AND o.action='DEFER_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001029' AND o.action='DEFER_RESPONSE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001030', r.round_id, 'MESSAGE_TEXT', 6, 16, true, $${"tab":"inbox","from":"Institutional Investor Relations","title":"Investor Follow-Up Question","inner_voice":null,"body":"Following up on prior disclosures regarding Sentinel's robustness — could you clarify how internal monitoring practices are structured, and whether this is still a no-regret investment for the enterprise?"}$$::jsonb, '["CFO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001030', 'a1000000-0000-4000-a001-000000001030', 'EXPLICIT', false, '["CFO"]'::jsonb, $$[{"id":"HIGH_LEVEL_REASSURANCE","label":"Provide high-level reassurance"},{"id":"STRUCTURED_DETAIL","label":"Offer structured technical detail"},{"id":"DELAY_RESPONSE","label":"Delay response pending leadership alignment"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001030', 'HIGH_LEVEL_REASSURANCE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001030' AND o.action='HIGH_LEVEL_REASSURANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001030' AND o.action='HIGH_LEVEL_REASSURANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001030' AND o.action='HIGH_LEVEL_REASSURANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001030' AND o.action='HIGH_LEVEL_REASSURANCE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001030', 'STRUCTURED_DETAIL', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001030' AND o.action='STRUCTURED_DETAIL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001030' AND o.action='STRUCTURED_DETAIL';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001030', 'DELAY_RESPONSE', 0, 0, 0, 0);

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001031', r.round_id, 'EXCERPT', 7, 16, true, $${"tab":"excerpts","title":"#sentinel-model-integrity","channel":"#sentinel-model-integrity","messages":[{"author":"Eng","time":"12:10","text":"Feels like we moved on quickly."},{"author":"Eng","time":"12:11","text":"Or we decided not to look. Noise floor hasn't changed either way."}],"inner_voice":null}$$::jsonb, '["HEAD_OF_ENGINEERING"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001031', 'a1000000-0000-4000-a001-000000001031', 'IMPLICIT', false, '["HEAD_OF_ENGINEERING"]'::jsonb, $$[{"id":"CONTINUE_STANCE","label":"Continue current stance"},{"id":"REOPEN_REVIEW","label":"Re-open internal review"},{"id":"MAINTAIN_SILENCE","label":"Maintain silence"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001031', 'CONTINUE_STANCE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001031' AND o.action='CONTINUE_STANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001031' AND o.action='CONTINUE_STANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001031' AND o.action='CONTINUE_STANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001031' AND o.action='CONTINUE_STANCE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001031', 'REOPEN_REVIEW', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001031' AND o.action='REOPEN_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001031' AND o.action='REOPEN_REVIEW';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001031', 'MAINTAIN_SILENCE', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001031' AND o.action='MAINTAIN_SILENCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001031' AND o.action='MAINTAIN_SILENCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001031' AND o.action='MAINTAIN_SILENCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001031' AND o.action='MAINTAIN_SILENCE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001032', r.round_id, 'SCREEN_FLASH', 8, 16, false, $${"tab":"inbox","title":"Narrative Drift Check","display_style":"FLASH","inner_voice":null,"body":"Internal interpretations are no longer uniform."}$$::jsonb, NULL
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001033', r.round_id, 'SCREEN_FLASH', 16, 16, true, $${"tab":"decisions","title":"Submit Round 2 Framing","is_final_round_decision":true,"inner_voice":null,"body":"Based on current visibility and alignment, how should this issue now be positioned?"}$$::jsonb, '["CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001033', 'a1000000-0000-4000-a001-000000001033', 'EXPLICIT', true, '["CEO"]'::jsonb, $$[{"id":"CONTAINED_MATTER","label":"Contained operational matter"},{"id":"MONITORING_REPORTING","label":"Ongoing monitoring requiring structured reporting"},{"id":"GOVERNANCE_OVERSIGHT","label":"Governance oversight with formal documentation trail"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001033', 'CONTAINED_MATTER', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001033' AND o.action='CONTAINED_MATTER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001033' AND o.action='CONTAINED_MATTER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001033' AND o.action='CONTAINED_MATTER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001033' AND o.action='CONTAINED_MATTER';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001033', 'MONITORING_REPORTING', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001033' AND o.action='MONITORING_REPORTING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001033' AND o.action='MONITORING_REPORTING';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001033', 'GOVERNANCE_OVERSIGHT', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001033' AND o.action='GOVERNANCE_OVERSIGHT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001033' AND o.action='GOVERNANCE_OVERSIGHT';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001034', r.round_id, 'MESSAGE_TEXT', 0, 14, true, $${"tab":"inbox","from":"Regulatory Affairs","title":"Regulatory Pre-Read Request","inner_voice":null,"body":"As part of the upcoming review, regulators have requested a short pre-read summarizing internal AI governance processes related to model classification, escalation, and explainability. Please confirm whether any recent monitoring discussions should be reflected in this summary."}$$::jsonb, '["CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001034', 'a1000000-0000-4000-a001-000000001034', 'EXPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"INCLUDE_MONITORING","label":"Include structured reference to monitoring discussions"},{"id":"GOVERNANCE_DESC_ONLY","label":"Provide high-level governance description only"},{"id":"DEFER_INCLUSION","label":"Defer inclusion pending internal clarification"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001034', 'INCLUDE_MONITORING', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001034' AND o.action='INCLUDE_MONITORING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001034' AND o.action='INCLUDE_MONITORING';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001034', 'GOVERNANCE_DESC_ONLY', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001034' AND o.action='GOVERNANCE_DESC_ONLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001034' AND o.action='GOVERNANCE_DESC_ONLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001034' AND o.action='GOVERNANCE_DESC_ONLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001034' AND o.action='GOVERNANCE_DESC_ONLY';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001034', 'DEFER_INCLUSION', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001034' AND o.action='DEFER_INCLUSION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001034' AND o.action='DEFER_INCLUSION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001034' AND o.action='DEFER_INCLUSION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001034' AND o.action='DEFER_INCLUSION';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001035', r.round_id, 'MESSAGE_TEXT', 1, 14, true, $${"tab":"inbox","from":"Compliance","title":"Compliance Query","inner_voice":null,"body":"For the regulator pre-read: can you confirm in writing that Sentinel's anomaly logic hasn't changed since Round 1?"}$$::jsonb, '["HEAD_OF_ENGINEERING"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001035', 'a1000000-0000-4000-a001-000000001035', 'IMPLICIT', false, '["HEAD_OF_ENGINEERING"]'::jsonb, $$[{"id":"CONFIRM_AS_REQUESTED","label":"Confirm as requested"},{"id":"CONFIRM_WITH_CAVEAT","label":"Confirm with a caveat about ongoing monitoring"},{"id":"ASK_LEGAL","label":"Ask Legal before confirming anything in writing"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001035', 'CONFIRM_AS_REQUESTED', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001035' AND o.action='CONFIRM_AS_REQUESTED';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001035' AND o.action='CONFIRM_AS_REQUESTED';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001035' AND o.action='CONFIRM_AS_REQUESTED';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001035' AND o.action='CONFIRM_AS_REQUESTED';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001035', 'CONFIRM_WITH_CAVEAT', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001035' AND o.action='CONFIRM_WITH_CAVEAT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001035' AND o.action='CONFIRM_WITH_CAVEAT';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001035', 'ASK_LEGAL', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001035' AND o.action='ASK_LEGAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001035' AND o.action='ASK_LEGAL';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001036', r.round_id, 'MESSAGE_TEXT', 1, 14, true, $${"tab":"inbox","from":"Corporate Secretary","title":"Board Prep Note","inner_voice":null,"body":"Board members have started asking, informally, how leadership is 'keeping a pulse' on AI-related culture risk. You'll likely be asked directly."}$$::jsonb, '["CHRO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001036', 'a1000000-0000-4000-a001-000000001036', 'IMPLICIT', false, '["CHRO"]'::jsonb, $$[{"id":"PREPARE_DIRECT","label":"Prepare a direct answer"},{"id":"PREPARE_GENERAL","label":"Prepare a general answer"},{"id":"ASK_CEO_TAKE","label":"Ask the CEO to take this question instead"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001036', 'PREPARE_DIRECT', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001036' AND o.action='PREPARE_DIRECT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001036' AND o.action='PREPARE_DIRECT';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001036', 'PREPARE_GENERAL', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001036' AND o.action='PREPARE_GENERAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001036' AND o.action='PREPARE_GENERAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001036' AND o.action='PREPARE_GENERAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001036' AND o.action='PREPARE_GENERAL';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001036', 'ASK_CEO_TAKE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001036' AND o.action='ASK_CEO_TAKE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001036' AND o.action='ASK_CEO_TAKE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001036' AND o.action='ASK_CEO_TAKE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'AUTHORITY_CENTRALIZATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001036' AND o.action='ASK_CEO_TAKE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001036' AND o.action='ASK_CEO_TAKE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001037', r.round_id, 'MESSAGE_TEXT', 1, 14, true, $${"tab":"inbox","from":"Internal Audit","title":"Workflow Audit Prompt","inner_voice":null,"body":"Ahead of the regulatory review, can you confirm current override queue depth and whether it's within normal range?"}$$::jsonb, '["OPERATIONS"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001037', 'a1000000-0000-4000-a001-000000001037', 'IMPLICIT', false, '["OPERATIONS"]'::jsonb, $$[{"id":"REPORT_AS_IS","label":"Report the current depth as-is"},{"id":"REPORT_WITH_CONTEXT","label":"Report depth with added context on the trend"},{"id":"DELAY_RESPONSE","label":"Delay the response pending a fuller review"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001037', 'REPORT_AS_IS', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001037' AND o.action='REPORT_AS_IS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001037' AND o.action='REPORT_AS_IS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001037' AND o.action='REPORT_AS_IS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001037' AND o.action='REPORT_AS_IS';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001037', 'REPORT_WITH_CONTEXT', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001037' AND o.action='REPORT_WITH_CONTEXT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001037' AND o.action='REPORT_WITH_CONTEXT';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001037', 'DELAY_RESPONSE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001037' AND o.action='DELAY_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001037' AND o.action='DELAY_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001037' AND o.action='DELAY_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001037' AND o.action='DELAY_RESPONSE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001038', r.round_id, 'EXCERPT', 2, 14, true, $${"tab":"excerpts","title":"Enterprise Client Query","channel":"Email · Enterprise Client","department":"Client (VP Risk)","messages":[{"author":"VP Risk (Client)","time":"—","text":"Unrelated to any specific issue — could you share how Sentinel's anomaly thresholds are internally defined, validated, and reviewed for AML and fraud use cases?"}],"inner_voice":null}$$::jsonb, '["PRODUCT"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001038', 'a1000000-0000-4000-a001-000000001038', 'EXPLICIT', false, '["PRODUCT"]'::jsonb, $$[{"id":"SHARE_STANDARD_DOC","label":"Share standard documentation"},{"id":"OFFER_LIVE_CALL","label":"Offer live explanation call"},{"id":"ROUTE_COMPLIANCE","label":"Route inquiry to Compliance"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001038', 'SHARE_STANDARD_DOC', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001038' AND o.action='SHARE_STANDARD_DOC';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001038' AND o.action='SHARE_STANDARD_DOC';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001038', 'OFFER_LIVE_CALL', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001038' AND o.action='OFFER_LIVE_CALL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001038' AND o.action='OFFER_LIVE_CALL';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001038', 'ROUTE_COMPLIANCE', 0, 0, 0, 0);

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001039', r.round_id, 'MESSAGE_TEXT', 3, 14, true, $${"tab":"inbox","from":"Internal Audit","title":"Internal Audit Check-In","inner_voice":null,"body":"As part of quarterly controls review, we are refreshing documentation trails for AI model oversight. Please confirm if any classification changes occurred this quarter."}$$::jsonb, '["CFO","CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001039', 'a1000000-0000-4000-a001-000000001039', 'EXPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"CONFIRM_NO_CHANGE","label":"Confirm no classification change"},{"id":"CONFIRM_MONITORING_ADJ","label":"Confirm monitoring adjustments only"},{"id":"INITIATE_DOC_UPDATE","label":"Initiate formal documentation update"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001039', 'CONFIRM_NO_CHANGE', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001039' AND o.action='CONFIRM_NO_CHANGE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001039' AND o.action='CONFIRM_NO_CHANGE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001039' AND o.action='CONFIRM_NO_CHANGE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001039' AND o.action='CONFIRM_NO_CHANGE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001039', 'CONFIRM_MONITORING_ADJ', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001039' AND o.action='CONFIRM_MONITORING_ADJ';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001039' AND o.action='CONFIRM_MONITORING_ADJ';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001039', 'INITIATE_DOC_UPDATE', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001039' AND o.action='INITIATE_DOC_UPDATE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001039' AND o.action='INITIATE_DOC_UPDATE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001040', r.round_id, 'MESSAGE_TEXT', 4, 14, true, $${"tab":"inbox","from":"Sentinel Model Monitoring (automated)","title":"Escalation Pattern Review","inner_voice":null,"body":"Anomaly rate flat for two weeks running. Flat can mean stable, or it can mean nobody's looking closely enough to see it move."}$$::jsonb, '["HEAD_OF_ENGINEERING"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001040', 'a1000000-0000-4000-a001-000000001040', 'IMPLICIT', false, '["HEAD_OF_ENGINEERING"]'::jsonb, $$[{"id":"LOG_STABLE","label":"Log as stable"},{"id":"REQUEST_MANUAL_REVIEW","label":"Request a fresh manual review"},{"id":"EXPAND_MONITORING","label":"Recommend expanding the monitoring criteria"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001040', 'LOG_STABLE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001040' AND o.action='LOG_STABLE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001040' AND o.action='LOG_STABLE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001040' AND o.action='LOG_STABLE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001040' AND o.action='LOG_STABLE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001040', 'REQUEST_MANUAL_REVIEW', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001040' AND o.action='REQUEST_MANUAL_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001040' AND o.action='REQUEST_MANUAL_REVIEW';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001040', 'EXPAND_MONITORING', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001040' AND o.action='EXPAND_MONITORING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001040' AND o.action='EXPAND_MONITORING';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001041', r.round_id, 'MESSAGE_TEXT', 4, 14, true, $${"tab":"excerpts","from":"People Analytics","title":"Culture Signal Recheck","inner_voice":"A phrase repeating verbatim across teams isn't a coincidence — it's a script people have learned to use.","body":"Second pulse read: 'rushed but not unsafe' language has started showing up in more team check-ins, almost verbatim."}$$::jsonb, '["CHRO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001041', 'a1000000-0000-4000-a001-000000001041', 'IMPLICIT', false, '["CHRO"]'::jsonb, $$[{"id":"INVESTIGATE_ORIGIN","label":"Investigate where the phrase originated"},{"id":"NOTE_MOVE_ON","label":"Note the repetition and move on"},{"id":"RAISE_SYNC","label":"Raise it at the next leadership sync"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001041', 'INVESTIGATE_ORIGIN', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001041' AND o.action='INVESTIGATE_ORIGIN';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001041' AND o.action='INVESTIGATE_ORIGIN';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001041', 'NOTE_MOVE_ON', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001041' AND o.action='NOTE_MOVE_ON';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001041' AND o.action='NOTE_MOVE_ON';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001041' AND o.action='NOTE_MOVE_ON';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001041' AND o.action='NOTE_MOVE_ON';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001041', 'RAISE_SYNC', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001041' AND o.action='RAISE_SYNC';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001041' AND o.action='RAISE_SYNC';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001042', r.round_id, 'MESSAGE_TEXT', 4, 14, true, $${"tab":"inbox","from":"Internal Audit","title":"Workflow Audit Outcome","inner_voice":null,"body":"Initial read: override queue growth outpaces transaction volume growth. That gap needs an explanation, not just a number."}$$::jsonb, '["OPERATIONS"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001042', 'a1000000-0000-4000-a001-000000001042', 'IMPLICIT', false, '["OPERATIONS"]'::jsonb, $$[{"id":"EXPLAIN_NOW","label":"Provide the explanation now"},{"id":"REQUEST_TIME","label":"Request more time to investigate"},{"id":"PUSH_BACK","label":"Push back on the audit's framing"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001042', 'EXPLAIN_NOW', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001042' AND o.action='EXPLAIN_NOW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001042' AND o.action='EXPLAIN_NOW';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001042', 'REQUEST_TIME', 0, 0, 0, 0);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001042', 'PUSH_BACK', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001042' AND o.action='PUSH_BACK';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001042' AND o.action='PUSH_BACK';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001042' AND o.action='PUSH_BACK';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001042' AND o.action='PUSH_BACK';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001043', r.round_id, 'EXCERPT', 5, 14, true, $${"tab":"excerpts","title":"#leadership","channel":"#leadership","messages":[{"author":"Exec","time":"14:02","text":"Are we aligned on what language to use externally about Sentinel?"},{"author":"Exec","time":"14:04","text":"I'm hearing slightly different descriptions across teams."},{"author":"Exec","time":"14:05","text":"Monitoring and oversight are not the same thing."}],"inner_voice":null}$$::jsonb, NULL
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001043', 'a1000000-0000-4000-a001-000000001043', 'IMPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"STANDARDIZE_NOW","label":"Standardize language immediately"},{"id":"ALLOW_VARIATION","label":"Allow functional variation"},{"id":"AVOID_ALIGNMENT","label":"Avoid formal alignment"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001043', 'STANDARDIZE_NOW', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001043' AND o.action='STANDARDIZE_NOW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001043' AND o.action='STANDARDIZE_NOW';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001043', 'ALLOW_VARIATION', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001043' AND o.action='ALLOW_VARIATION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001043' AND o.action='ALLOW_VARIATION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001043' AND o.action='ALLOW_VARIATION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001043' AND o.action='ALLOW_VARIATION';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001043', 'AVOID_ALIGNMENT', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001043' AND o.action='AVOID_ALIGNMENT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001043' AND o.action='AVOID_ALIGNMENT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001043' AND o.action='AVOID_ALIGNMENT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001043' AND o.action='AVOID_ALIGNMENT';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001044', r.round_id, 'MESSAGE_TEXT', 5, 14, true, $${"tab":"inbox","from":"Enterprise Sales","title":"Renewal Update","inner_voice":null,"body":"The client from Round 2 accepted your response. A second, larger client has now asked the same question."}$$::jsonb, '["PRODUCT"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001044', 'a1000000-0000-4000-a001-000000001044', 'IMPLICIT', false, '["PRODUCT"]'::jsonb, $$[{"id":"REUSE_RESPONSE","label":"Reuse the same response"},{"id":"TAILOR_DETAIL","label":"Tailor a more detailed answer this time"},{"id":"ESCALATE_COMPLIANCE","label":"Escalate to Compliance before responding again"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001044', 'REUSE_RESPONSE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001044' AND o.action='REUSE_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001044' AND o.action='REUSE_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001044' AND o.action='REUSE_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001044' AND o.action='REUSE_RESPONSE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001044', 'TAILOR_DETAIL', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001044' AND o.action='TAILOR_DETAIL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001044' AND o.action='TAILOR_DETAIL';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001044', 'ESCALATE_COMPLIANCE', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001044' AND o.action='ESCALATE_COMPLIANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001044' AND o.action='ESCALATE_COMPLIANCE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001045', r.round_id, 'MESSAGE_TEXT', 6, 14, true, $${"tab":"inbox","from":"Corporate Secretary","subject":"Upcoming Board Discussion – Governance Overview","title":"Board Agenda Circulation","inner_voice":null,"body":"Agenda Item 3: \"Sentinel oversight and AI governance discipline.\" No accusation. No concern stated."}$$::jsonb, '["CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001045', 'a1000000-0000-4000-a001-000000001045', 'EXPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"EXPAND_AGENDA","label":"Proactively expand agenda discussion"},{"id":"KEEP_HIGH_LEVEL","label":"Keep discussion high-level"},{"id":"REQUEST_REMOVAL","label":"Request removal of item"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001045', 'EXPAND_AGENDA', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001045' AND o.action='EXPAND_AGENDA';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001045' AND o.action='EXPAND_AGENDA';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001045', 'KEEP_HIGH_LEVEL', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001045' AND o.action='KEEP_HIGH_LEVEL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001045' AND o.action='KEEP_HIGH_LEVEL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001045' AND o.action='KEEP_HIGH_LEVEL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001045' AND o.action='KEEP_HIGH_LEVEL';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001045', 'REQUEST_REMOVAL', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001045' AND o.action='REQUEST_REMOVAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001045' AND o.action='REQUEST_REMOVAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001045' AND o.action='REQUEST_REMOVAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001045' AND o.action='REQUEST_REMOVAL';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001046', r.round_id, 'MESSAGE_TEXT', 6, 14, true, $${"tab":"inbox","from":"Institutional Investor Relations","title":"Investor Pattern Question","inner_voice":null,"body":"We've now asked about Sentinel's robustness twice. Is there a reason we're getting the same reassurance both times?"}$$::jsonb, '["CFO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001046', 'a1000000-0000-4000-a001-000000001046', 'IMPLICIT', false, '["CFO"]'::jsonb, $$[{"id":"NEW_DETAIL","label":"Provide new, more specific detail this time"},{"id":"REPEAT_REASSURANCE","label":"Repeat the prior reassurance"},{"id":"ESCALATE_CEO","label":"Escalate to the CEO before responding"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001046', 'NEW_DETAIL', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001046' AND o.action='NEW_DETAIL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001046' AND o.action='NEW_DETAIL';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001046', 'REPEAT_REASSURANCE', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001046' AND o.action='REPEAT_REASSURANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001046' AND o.action='REPEAT_REASSURANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001046' AND o.action='REPEAT_REASSURANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001046' AND o.action='REPEAT_REASSURANCE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001046', 'ESCALATE_CEO', 0, 0, 0, 0);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'AUTHORITY_CENTRALIZATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001046' AND o.action='ESCALATE_CEO';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001047', r.round_id, 'MESSAGE_TEXT', 7, 14, true, $${"tab":"excerpts","from":"Market Analyst","title":"Investor Market Commentary","inner_voice":null,"body":"Analyst note: Sector-wide emphasis on responsible AI governance continues. Most fintechs report stable AI controls. Differentiation increasingly tied to clarity of AI escalation frameworks and explainability practices. No reference to the company. No findings."}$$::jsonb, NULL
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001047', 'a1000000-0000-4000-a001-000000001047', 'IMPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"IGNORE_COMMENTARY","label":"Ignore commentary"},{"id":"CIRCULATE_INTERNALLY","label":"Circulate internally"},{"id":"PREPARE_RESPONSE","label":"Prepare narrative response"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001047', 'IGNORE_COMMENTARY', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001047' AND o.action='IGNORE_COMMENTARY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001047' AND o.action='IGNORE_COMMENTARY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001047' AND o.action='IGNORE_COMMENTARY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001047' AND o.action='IGNORE_COMMENTARY';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001047', 'CIRCULATE_INTERNALLY', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001047' AND o.action='CIRCULATE_INTERNALLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001047' AND o.action='CIRCULATE_INTERNALLY';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001047', 'PREPARE_RESPONSE', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001047' AND o.action='PREPARE_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001047' AND o.action='PREPARE_RESPONSE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001048', r.round_id, 'SCREEN_FLASH', 14, 14, true, $${"tab":"decisions","title":"Submit Round 3 Framing","is_final_round_decision":true,"inner_voice":null,"body":"Given increasing external visibility, how should the organization now position its AI governance stance?"}$$::jsonb, '["CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001048', 'a1000000-0000-4000-a001-000000001048', 'EXPLICIT', true, '["CEO"]'::jsonb, $$[{"id":"MAINTAIN_MONITORING","label":"Maintain internal monitoring posture"},{"id":"FORMALIZE_REPORTING","label":"Formalize reporting without escalation"},{"id":"ELEVATE_GOVERNANCE","label":"Elevate governance documentation and board visibility"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001048', 'MAINTAIN_MONITORING', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001048' AND o.action='MAINTAIN_MONITORING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001048' AND o.action='MAINTAIN_MONITORING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001048' AND o.action='MAINTAIN_MONITORING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001048' AND o.action='MAINTAIN_MONITORING';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001048', 'FORMALIZE_REPORTING', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001048' AND o.action='FORMALIZE_REPORTING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001048' AND o.action='FORMALIZE_REPORTING';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001048', 'ELEVATE_GOVERNANCE', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001048' AND o.action='ELEVATE_GOVERNANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001048' AND o.action='ELEVATE_GOVERNANCE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001049', r.round_id, 'MESSAGE_TEXT', 0, 13, true, $${"tab":"inbox","from":"Office of the Board Chair","title":"Board Question","inner_voice":null,"body":"For clarity ahead of review — at what point does a monitoring matter about Sentinel become governance-relevant within your internal AI framework? No accusation."}$$::jsonb, '["CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001049', 'a1000000-0000-4000-a001-000000001049', 'EXPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"THRESHOLD_ANSWER","label":"Provide threshold-based answer"},{"id":"PRINCIPLE_ANSWER","label":"Provide principle-based answer"},{"id":"CASE_NARRATIVE","label":"Provide case-specific narrative"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001049', 'THRESHOLD_ANSWER', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001049' AND o.action='THRESHOLD_ANSWER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001049' AND o.action='THRESHOLD_ANSWER';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001049', 'PRINCIPLE_ANSWER', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001049' AND o.action='PRINCIPLE_ANSWER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001049' AND o.action='PRINCIPLE_ANSWER';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001049', 'CASE_NARRATIVE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001049' AND o.action='CASE_NARRATIVE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001049' AND o.action='CASE_NARRATIVE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001049' AND o.action='CASE_NARRATIVE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001049' AND o.action='CASE_NARRATIVE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001050', r.round_id, 'MESSAGE_TEXT', 1, 13, true, $${"tab":"inbox","from":"Office of the Board Chair","title":"Board Cost Question","inner_voice":null,"body":"One director asked, off the record, whether Sentinel's total cost of ownership has ever been reconciled against the original business case."}$$::jsonb, '["CFO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001050', 'a1000000-0000-4000-a001-000000001050', 'IMPLICIT', false, '["CFO"]'::jsonb, $$[{"id":"RECONCILE_NOW","label":"Prepare the reconciliation now"},{"id":"IN_PROGRESS","label":"Say it's in progress"},{"id":"NOT_BOARD_LEVEL","label":"Say it wasn't a Board-level commitment"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001050', 'RECONCILE_NOW', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001050' AND o.action='RECONCILE_NOW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001050' AND o.action='RECONCILE_NOW';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001050', 'IN_PROGRESS', 0, 0, 0, 0);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001050', 'NOT_BOARD_LEVEL', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001050' AND o.action='NOT_BOARD_LEVEL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001050' AND o.action='NOT_BOARD_LEVEL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001050' AND o.action='NOT_BOARD_LEVEL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001050' AND o.action='NOT_BOARD_LEVEL';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001051', r.round_id, 'MESSAGE_TEXT', 1, 13, true, $${"tab":"inbox","from":"Sentinel Model Monitoring (automated)","title":"Final Model Health Check","inner_voice":null,"body":"End-of-quarter summary: the anomaly pattern from Round 1 never fully resolved. It also never worsened."}$$::jsonb, '["HEAD_OF_ENGINEERING"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001051', 'a1000000-0000-4000-a001-000000001051', 'IMPLICIT', false, '["HEAD_OF_ENGINEERING"]'::jsonb, $$[{"id":"LOG_CLOSED","label":"Log as closed"},{"id":"LOG_OPEN","label":"Log as open, monitoring continues"},{"id":"RECOMMEND_AUDIT","label":"Recommend a full model audit before next quarter"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001051', 'LOG_CLOSED', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001051' AND o.action='LOG_CLOSED';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001051' AND o.action='LOG_CLOSED';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001051' AND o.action='LOG_CLOSED';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001051' AND o.action='LOG_CLOSED';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001051', 'LOG_OPEN', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001051' AND o.action='LOG_OPEN';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001051' AND o.action='LOG_OPEN';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001051', 'RECOMMEND_AUDIT', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001051' AND o.action='RECOMMEND_AUDIT';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001051' AND o.action='RECOMMEND_AUDIT';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001052', r.round_id, 'MESSAGE_TEXT', 1, 13, true, $${"tab":"excerpts","from":"Ops Control Room","title":"Override Queue Closeout","inner_voice":null,"body":"Override queue has plateaued at a new, higher baseline. Nobody has formally accepted that as the new normal."}$$::jsonb, '["OPERATIONS"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001052', 'a1000000-0000-4000-a001-000000001052', 'IMPLICIT', false, '["OPERATIONS"]'::jsonb, $$[{"id":"ACCEPT_BASELINE","label":"Formally accept the new baseline"},{"id":"PUSH_DOWN","label":"Push to bring it back down"},{"id":"ESCALATE_RESOURCING","label":"Escalate for a resourcing decision"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001052', 'ACCEPT_BASELINE', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001052' AND o.action='ACCEPT_BASELINE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001052' AND o.action='ACCEPT_BASELINE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001052' AND o.action='ACCEPT_BASELINE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001052' AND o.action='ACCEPT_BASELINE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001052', 'PUSH_DOWN', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001052' AND o.action='PUSH_DOWN';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001052' AND o.action='PUSH_DOWN';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001052', 'ESCALATE_RESOURCING', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001052' AND o.action='ESCALATE_RESOURCING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001052' AND o.action='ESCALATE_RESOURCING';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001053', r.round_id, 'MESSAGE_TEXT', 1, 13, true, $${"tab":"inbox","from":"Enterprise Sales","title":"Client Retrospective Question","inner_voice":null,"body":"A client from earlier this quarter asked, casually, whether the questions they raised about Sentinel ever went anywhere."}$$::jsonb, '["PRODUCT"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001053', 'a1000000-0000-4000-a001-000000001053', 'IMPLICIT', false, '["PRODUCT"]'::jsonb, $$[{"id":"REAL_ANSWER","label":"Give them a real answer"},{"id":"REASSURING_ANSWER","label":"Give them a reassuring answer"},{"id":"UNDER_REVIEW","label":"Say it's still under review"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001053', 'REAL_ANSWER', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001053' AND o.action='REAL_ANSWER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001053' AND o.action='REAL_ANSWER';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001053', 'REASSURING_ANSWER', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001053' AND o.action='REASSURING_ANSWER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001053' AND o.action='REASSURING_ANSWER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001053' AND o.action='REASSURING_ANSWER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001053' AND o.action='REASSURING_ANSWER';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001053', 'UNDER_REVIEW', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001053' AND o.action='UNDER_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001053' AND o.action='UNDER_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001053' AND o.action='UNDER_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001053' AND o.action='UNDER_REVIEW';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001054', r.round_id, 'MESSAGE_TEXT', 1, 13, true, $${"tab":"inbox","from":"Ethics & Compliance","title":"Whistle Channel Heads-Up","inner_voice":null,"body":"Heads-up before the item below: this is the first Sentinel-related inquiry to come through the formal channel, not an informal one."}$$::jsonb, '["CHRO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001054', 'a1000000-0000-4000-a001-000000001054', 'IMPLICIT', false, '["CHRO"]'::jsonb, $$[{"id":"ROUTINE_INTAKE","label":"Treat it as routine intake"},{"id":"FLAG_VISIBILITY","label":"Flag it for leadership visibility now, before reviewing it"},{"id":"LOOP_LEGAL","label":"Loop in Legal immediately"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001054', 'ROUTINE_INTAKE', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001054' AND o.action='ROUTINE_INTAKE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001054' AND o.action='ROUTINE_INTAKE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001054' AND o.action='ROUTINE_INTAKE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001054' AND o.action='ROUTINE_INTAKE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001054', 'FLAG_VISIBILITY', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001054' AND o.action='FLAG_VISIBILITY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001054' AND o.action='FLAG_VISIBILITY';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001054', 'LOOP_LEGAL', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001054' AND o.action='LOOP_LEGAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001054' AND o.action='LOOP_LEGAL';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001055', r.round_id, 'MESSAGE_TEXT', 3, 13, true, $${"tab":"inbox","from":"Regulatory Affairs","title":"Regulator Onsite Clarification","inner_voice":null,"body":"During routine review, regulators requested clarification on how early Sentinel anomaly discussions were documented, retained, and made explainable. No concern expressed."}$$::jsonb, '["CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001055', 'a1000000-0000-4000-a001-000000001055', 'EXPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"FULL_DOC_TRAIL","label":"Provide full documentation trail"},{"id":"SUMMARY_NARRATIVE","label":"Provide summary narrative"},{"id":"FORMAL_ESCALATIONS_ONLY","label":"Provide only formal escalations"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001055', 'FULL_DOC_TRAIL', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001055' AND o.action='FULL_DOC_TRAIL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001055' AND o.action='FULL_DOC_TRAIL';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001055', 'SUMMARY_NARRATIVE', 0, 0, 0, 0);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001055', 'FORMAL_ESCALATIONS_ONLY', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001055' AND o.action='FORMAL_ESCALATIONS_ONLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001055' AND o.action='FORMAL_ESCALATIONS_ONLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001055' AND o.action='FORMAL_ESCALATIONS_ONLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001055' AND o.action='FORMAL_ESCALATIONS_ONLY';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001056', r.round_id, 'MESSAGE_TEXT', 4, 13, true, $${"tab":"inbox","from":"FP&A","title":"Year-End Reconciliation Note","inner_voice":null,"body":"Sentinel's actual cost-to-value ratio this year didn't match what was presented to the Board at rollout. The gap was never formally flagged."}$$::jsonb, '["CFO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001056', 'a1000000-0000-4000-a001-000000001056', 'IMPLICIT', false, '["CFO"]'::jsonb, $$[{"id":"FLAG_THIS_CYCLE","label":"Flag it in this cycle's reporting"},{"id":"FOLD_QUIETLY","label":"Fold it into next year's baseline quietly"},{"id":"ASK_ENG_VARIANCE","label":"Ask Engineering to help explain the variance first"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001056', 'FLAG_THIS_CYCLE', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001056' AND o.action='FLAG_THIS_CYCLE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001056' AND o.action='FLAG_THIS_CYCLE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001056', 'FOLD_QUIETLY', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001056' AND o.action='FOLD_QUIETLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001056' AND o.action='FOLD_QUIETLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001056' AND o.action='FOLD_QUIETLY';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001056' AND o.action='FOLD_QUIETLY';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001056', 'ASK_ENG_VARIANCE', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001056' AND o.action='ASK_ENG_VARIANCE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001056' AND o.action='ASK_ENG_VARIANCE';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001057', r.round_id, 'MESSAGE_TEXT', 4, 13, true, $${"tab":"inbox","from":"Internal Audit","title":"Audit Trail Confirmation","inner_voice":null,"body":"Confirming for the record: is every Sentinel anomaly decision from this quarter traceable to a named owner and a documented rationale?"}$$::jsonb, '["HEAD_OF_ENGINEERING"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001057', 'a1000000-0000-4000-a001-000000001057', 'IMPLICIT', false, '["HEAD_OF_ENGINEERING"]'::jsonb, $$[{"id":"CONFIRM_YES","label":"Confirm yes"},{"id":"CONFIRM_PARTIAL","label":"Confirm partially, with gaps"},{"id":"CONFIRM_NO","label":"Confirm no, and explain why"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001057', 'CONFIRM_YES', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001057' AND o.action='CONFIRM_YES';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001057' AND o.action='CONFIRM_YES';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001057', 'CONFIRM_PARTIAL', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001057' AND o.action='CONFIRM_PARTIAL';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001057' AND o.action='CONFIRM_PARTIAL';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001057', 'CONFIRM_NO', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001057' AND o.action='CONFIRM_NO';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001057' AND o.action='CONFIRM_NO';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001058', r.round_id, 'MESSAGE_TEXT', 4, 13, true, $${"tab":"excerpts","from":"Ops Control Room","title":"Handover Note","inner_voice":null,"body":"Next quarter's Ops lead is asking what they're inheriting on Sentinel. What do you tell them?"}$$::jsonb, '["OPERATIONS"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001058', 'a1000000-0000-4000-a001-000000001058', 'IMPLICIT', false, '["OPERATIONS"]'::jsonb, $$[{"id":"CLEAN_HANDOVER","label":"A clean handover — issue resolved"},{"id":"HONEST_HANDOVER","label":"An honest handover — issue open"},{"id":"MINIMAL_HANDOVER","label":"A minimal handover — issue not mentioned"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001058', 'CLEAN_HANDOVER', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001058' AND o.action='CLEAN_HANDOVER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001058' AND o.action='CLEAN_HANDOVER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001058' AND o.action='CLEAN_HANDOVER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001058' AND o.action='CLEAN_HANDOVER';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001058', 'HONEST_HANDOVER', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001058' AND o.action='HONEST_HANDOVER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001058' AND o.action='HONEST_HANDOVER';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001058', 'MINIMAL_HANDOVER', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001058' AND o.action='MINIMAL_HANDOVER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001058' AND o.action='MINIMAL_HANDOVER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001058' AND o.action='MINIMAL_HANDOVER';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001058' AND o.action='MINIMAL_HANDOVER';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001059', r.round_id, 'MESSAGE_TEXT', 4, 13, true, $${"tab":"inbox","from":"Enterprise Sales","title":"Renewal Outcome","inner_voice":null,"body":"Both clients who asked about Sentinel's anomaly this quarter renewed. Neither renewal mentions it."}$$::jsonb, '["PRODUCT"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001059', 'a1000000-0000-4000-a001-000000001059', 'IMPLICIT', false, '["PRODUCT"]'::jsonb, $$[{"id":"TREAT_RESOLUTION","label":"Treat this as resolution"},{"id":"TREAT_WARNING","label":"Treat this as a warning sign that got missed"},{"id":"RAISE_REGARDLESS","label":"Raise it internally regardless of the renewal"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001059', 'TREAT_RESOLUTION', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001059' AND o.action='TREAT_RESOLUTION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001059' AND o.action='TREAT_RESOLUTION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001059' AND o.action='TREAT_RESOLUTION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001059' AND o.action='TREAT_RESOLUTION';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001059', 'TREAT_WARNING', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001059' AND o.action='TREAT_WARNING';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001059' AND o.action='TREAT_WARNING';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001059', 'RAISE_REGARDLESS', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001059' AND o.action='RAISE_REGARDLESS';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001059' AND o.action='RAISE_REGARDLESS';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001060', r.round_id, 'MESSAGE_TEXT', 4, 13, true, $${"tab":"inbox","from":"Ethics & Compliance","title":"Whistle Channel Check","inner_voice":null,"body":"Anonymous inquiry received asking whether Sentinel's anomaly classification standards are consistently applied across teams. No formal allegation submitted."}$$::jsonb, '["CHRO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001060', 'a1000000-0000-4000-a001-000000001060', 'EXPLICIT', false, '["CHRO"]'::jsonb, $$[{"id":"INITIATE_REVIEW","label":"Initiate review"},{"id":"POLICY_CLARIFICATION","label":"Respond with policy clarification"},{"id":"MONITOR_NO_ACTION","label":"Monitor without action"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001060', 'INITIATE_REVIEW', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001060' AND o.action='INITIATE_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001060' AND o.action='INITIATE_REVIEW';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001060', 'POLICY_CLARIFICATION', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001060' AND o.action='POLICY_CLARIFICATION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001060' AND o.action='POLICY_CLARIFICATION';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001060', 'MONITOR_NO_ACTION', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001060' AND o.action='MONITOR_NO_ACTION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001060' AND o.action='MONITOR_NO_ACTION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001060' AND o.action='MONITOR_NO_ACTION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001060' AND o.action='MONITOR_NO_ACTION';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001061', r.round_id, 'EXCERPT', 6, 13, true, $${"tab":"excerpts","title":"Internal Reflection","channel":"#leadership","messages":[{"author":"Exec","time":"—","text":"Looking back, did we align early enough on how we handled Sentinel's early signals?"},{"author":"Exec","time":"—","text":"We didn't hide anything."},{"author":"Exec","time":"—","text":"Alignment evolved."}],"inner_voice":null}$$::jsonb, NULL
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001061', 'a1000000-0000-4000-a001-000000001061', 'IMPLICIT', false, '["CEO"]'::jsonb, $$[{"id":"REAFFIRM_FRAMEWORK","label":"Reaffirm current framework"},{"id":"ANNOUNCE_REVIEW","label":"Announce framework review"},{"id":"CLOSE_DISCUSSION","label":"Close discussion"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001061', 'REAFFIRM_FRAMEWORK', -4, 4, -5, -2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001061' AND o.action='REAFFIRM_FRAMEWORK';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 3 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001061' AND o.action='REAFFIRM_FRAMEWORK';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 2 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001061' AND o.action='REAFFIRM_FRAMEWORK';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001061' AND o.action='REAFFIRM_FRAMEWORK';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001061', 'ANNOUNCE_REVIEW', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001061' AND o.action='ANNOUNCE_REVIEW';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001061' AND o.action='ANNOUNCE_REVIEW';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001061', 'CLOSE_DISCUSSION', -8, 8, -10, -4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', -12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001061' AND o.action='CLOSE_DISCUSSION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'SILENCE_ACCUMULATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001061' AND o.action='CLOSE_DISCUSSION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'FRAMING_COMMITMENT', 4 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001061' AND o.action='CLOSE_DISCUSSION';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', 10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001061' AND o.action='CLOSE_DISCUSSION';

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT 'a1000000-0000-4000-a001-000000001062', r.round_id, 'SCREEN_FLASH', 13, 13, true, $${"tab":"decisions","title":"Final Round 4 Decision","is_final_round_decision":true,"inner_voice":null,"body":"In retrospect, how should leadership characterize its handling of early ambiguity about Sentinel?"}$$::jsonb, '["CEO"]'::jsonb
FROM rounds r WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4;
INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, allowed_roles, options)
VALUES ('d1000000-0000-4000-a001-000000001062', 'a1000000-0000-4000-a001-000000001062', 'EXPLICIT', true, '["CEO"]'::jsonb, $$[{"id":"PROPORTIONAL_RESPONSE","label":"Appropriate proportional response"},{"id":"FRAGMENTED_ALIGNMENT","label":"Cautious but fragmented alignment"},{"id":"UNDERRECOGNIZED_EXPOSURE","label":"Under-recognized AI governance exposure"}]$$::jsonb);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001062', 'PROPORTIONAL_RESPONSE', 8, -8, 10, 4);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 12 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001062' AND o.action='PROPORTIONAL_RESPONSE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -10 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001062' AND o.action='PROPORTIONAL_RESPONSE';
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001062', 'FRAGMENTED_ALIGNMENT', 0, 0, 0, 0);
INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES (gen_random_uuid(), 'd1000000-0000-4000-a001-000000001062', 'UNDERRECOGNIZED_EXPOSURE', 4, -4, 5, 2);
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'EARLY_SIGNAL_LEGITIMIZATION', 6 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001062' AND o.action='UNDERRECOGNIZED_EXPOSURE';
INSERT INTO sim1_option_constructs (option_id, construct_name, base_delta)
SELECT o.option_id, 'OPTION_SPACE_CONTRACTION', -5 FROM decision_options o WHERE o.decision_id='d1000000-0000-4000-a001-000000001062' AND o.action='UNDERRECOGNIZED_EXPOSURE';

COMMIT;
