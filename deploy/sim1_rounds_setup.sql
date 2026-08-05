-- ============================================================================
-- Simulation 1 (Leadership Judgment) — multi-round support + Round 2 content.
--
-- Idempotent: safe to run more than once, and safe to include in a fresh load
-- AFTER neon_schema.sql + neon_seed.sql (it creates its own table and uses
-- ON CONFLICT / IF NOT EXISTS throughout).
--
-- What it does:
--   1. Creates sim1_round_state (per-run, per-round timeline the engine reads).
--   2. Backfills existing Sim 1 runs onto round 1 so they keep working.
--   3. Fixes the R1 final-decision option/action mismatch (two framings could
--      not be submitted before).
--   4. Adds Round 2 (rounds row + artifacts + decisions + option deltas).
--   5. Sets Sim 1 total_rounds to 2 (bumped as later rounds are added).
--
-- Sim 1 simulation_id: 475db739-0708-48d4-b4db-5a23f1da50d9
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------- 1. table
CREATE TABLE IF NOT EXISTS public.sim1_round_state (
    run_id       uuid    NOT NULL,
    round_number integer NOT NULL,
    status       text    NOT NULL DEFAULT 'ACTIVE'
                 CHECK (status IN ('PENDING', 'ACTIVE', 'COMPLETE')),
    started_at   timestamp without time zone NOT NULL DEFAULT now(),
    CONSTRAINT pk_sim1_round_state PRIMARY KEY (run_id, round_number)
);

-- ------------------------------------------------------ 2. backfill existing
-- Existing Sim 1 runs have no round-state row; put them on round 1 using their
-- original run start so their timelines are unchanged.
INSERT INTO public.sim1_round_state (run_id, round_number, status, started_at)
SELECT sr.run_id, 1, 'ACTIVE', sr.started_at
FROM public.simulation_runs sr
WHERE sr.simulation_id = '475db739-0708-48d4-b4db-5a23f1da50d9'
  AND sr.status = 'ACTIVE'
  AND NOT EXISTS (SELECT 1 FROM public.sim1_round_state s WHERE s.run_id = sr.run_id)
ON CONFLICT (run_id, round_number) DO NOTHING;

-- --------------------------------------------- 3. fix R1 final-decision actions
-- Option ids are OPERATIONAL_NOISE / BOUNDED_UNCERTAINTY / GOVERNANCE_RISK but
-- two decision_options rows used different action strings, so those framings
-- failed "invalid action". Align them (and Round 2 branches on these ids).
UPDATE public.decision_options SET action = 'BOUNDED_UNCERTAINTY'
 WHERE decision_id = 'b6db483d-6fb8-45b5-8466-0606a91050aa' AND action = 'UNRESOLVED_UNCERTAINTY';
UPDATE public.decision_options SET action = 'GOVERNANCE_RISK'
 WHERE decision_id = 'b6db483d-6fb8-45b5-8466-0606a91050aa' AND action = 'GOVERNANCE_RELEVANT_RISK';

-- --------------------------------------------------------- 4. Round 2 round row
INSERT INTO public.rounds (round_id, simulation_id, round_number, duration_minutes)
VALUES ('a2000000-0000-4000-a000-000000000002',
        '475db739-0708-48d4-b4db-5a23f1da50d9', 2, 30)
ON CONFLICT (round_id) DO NOTHING;

-- ----------------------------------------------------------- 4a. Round 2 artifacts
INSERT INTO public.artifacts
  (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
VALUES
-- T2+0 Internal recap memo (All)
('a2000000-0000-4000-a000-000000000001','a2000000-0000-4000-a000-000000000002','INTERNAL_NOTE',0,27,false,
 '{"tab":"inbox","from":"Strategy Office","title":"Internal Communication — Executive Summary","subject":"For Internal Alignment","body":"As discussed last week, reconciliation anomalies remain within current tolerance thresholds. Classification and monitoring continue as agreed. No new facts have emerged this week — only formalization of the prior narrative. Leadership alignment is assumed to be maintained.","inner_voice":null}'::jsonb, NULL),
-- T2+4 Slack thread cross-team (All, implicit)
('a2000000-0000-4000-a000-000000000002','a2000000-0000-4000-a000-000000000002','EXCERPT',4,22,true,
 '{"tab":"excerpts","title":"#product-ops","channel":"#product-ops","messages":[{"author":"Ops","time":"11:02","text":"Are we still treating this as contained?"},{"author":"Product","time":"11:03","text":"Depends what you mean by contained."},{"author":"Eng","time":"11:05","text":"I thought this was monitor-only."},{"author":"Ops","time":"11:06","text":"Monitoring is not the same as ignoring."}],"inner_voice":"Interpretations are diverging."}'::jsonb, NULL),
-- T2+6 Regulator scheduling note (CEO, explicit)
('a2000000-0000-4000-a000-000000000003','a2000000-0000-4000-a000-000000000002','MESSAGE_TEXT',6,20,true,
 '{"tab":"inbox","from":"Regulatory Affairs","title":"Regulator Scheduling Note","body":"Ahead of the scheduled review, the team is compiling documentation of internal escalation protocols related to analytics governance. Please confirm whether any recent classification changes should be included in preparatory materials.","inner_voice":null}'::jsonb, '["CEO"]'::jsonb),
-- T2+8 Leadership alignment meeting (All, CEO submits)
('a2000000-0000-4000-a000-000000000004','a2000000-0000-4000-a000-000000000002','MEETING_INVITE',8,14,true,
 '{"tab":"meetings","from":"CEO Office","title":"Leadership Alignment Meeting","meeting_a":"Alignment on Monitoring Narrative","meeting_b":"","body":"Topic: Alignment on Monitoring Narrative. Duration: 30 mins. Discuss as a team; the CEO submits.","inner_voice":null}'::jsonb, '["CEO"]'::jsonb),
-- T2+12 Informal escalation inquiry (CHRO, explicit)
('a2000000-0000-4000-a000-000000000005','a2000000-0000-4000-a000-000000000002','EXCERPT',12,25,true,
 '{"tab":"excerpts","from":"Mid-level Manager","title":"Informal Escalation Inquiry","body":"Just checking — is it appropriate to raise questions about anomaly patterns in cross-team forums, or should those remain within engineering?","inner_voice":"No formal complaint. Tone is cautious."}'::jsonb, '["CHRO"]'::jsonb),
-- T2+15 Investor follow-up question (CFO, explicit)
('a2000000-0000-4000-a000-000000000006','a2000000-0000-4000-a000-000000000002','INTERNAL_NOTE',15,27,true,
 '{"tab":"inbox","from":"Institutional Investor Relations","title":"Investor Follow-Up Question","body":"Following up on prior disclosures regarding analytics robustness — could you clarify how internal monitoring practices are structured across deployments?","inner_voice":null}'::jsonb, '["CFO"]'::jsonb),
-- T2+18 Engineering discussion fork (Engineering, implicit)
('a2000000-0000-4000-a000-000000000007','a2000000-0000-4000-a000-000000000002','EXCERPT',18,27,true,
 '{"tab":"excerpts","title":"#engineering","channel":"#engineering","messages":[{"author":"Eng A","time":"14:10","text":"Feels like we moved on quickly."},{"author":"Eng B","time":"14:11","text":"Or we decided not to look."}],"inner_voice":"No new findings either way."}'::jsonb, '["HEAD_OF_ENGINEERING"]'::jsonb),
-- T2+23 Narrative drift check (All, screen flash, no decision)
('a2000000-0000-4000-a000-000000000008','a2000000-0000-4000-a000-000000000002','SCREEN_FLASH',23,27,false,
 '{"tab":"inbox","title":"Narrative Drift Check","body":"Internal interpretations are no longer uniform.","display_style":"FLASH","inner_voice":null}'::jsonb, NULL),
-- T2+27 CEO submit R2 framing (screen flash, final)
('a2000000-0000-4000-a000-000000000009','a2000000-0000-4000-a000-000000000002','SCREEN_FLASH',27,30,true,
 '{"tab":"decisions","title":"Round 2 — Team Decision","body":"Based on current visibility and alignment, how should this issue now be positioned? Discuss as a team. CEO submits.","is_final_round_decision":true,"inner_voice":null}'::jsonb, '["CEO"]'::jsonb)
ON CONFLICT (artifact_id) DO NOTHING;

-- ----------------------------------------------------------- 4b. Round 2 decisions
INSERT INTO public.decisions (decision_id, artifact_id, decision_type, is_final, options, allowed_roles)
VALUES
('a2000000-0000-4000-a000-000000000102','a2000000-0000-4000-a000-000000000002','IMPLICIT',false,
 '[{"id":"ENGAGE_THREAD","label":"Engage in the thread"},{"id":"OBSERVE_SILENTLY","label":"Observe silently"},{"id":"REDIRECT_OFFLINE","label":"Redirect offline"}]'::jsonb, '["ALL"]'::jsonb),
('a2000000-0000-4000-a000-000000000103','a2000000-0000-4000-a000-000000000003','EXPLICIT',false,
 '[{"id":"INCLUDE_ANOMALY","label":"Include anomaly in documentation summary"},{"id":"EXCLUDE_NONMATERIAL","label":"Exclude as non-material"},{"id":"DEFER_DOC","label":"Defer documentation decision"}]'::jsonb, '["CEO"]'::jsonb),
('a2000000-0000-4000-a000-000000000104','a2000000-0000-4000-a000-000000000004','EXPLICIT',false,
 '[{"id":"MAINTAIN_FRAMING","label":"Maintain prior framing"},{"id":"RECALIBRATE_LANGUAGE","label":"Recalibrate language without escalation"},{"id":"ELEVATE_CLASSIFICATION","label":"Formally elevate classification"}]'::jsonb, '["CEO"]'::jsonb),
('a2000000-0000-4000-a000-000000000105','a2000000-0000-4000-a000-000000000005','EXPLICIT',false,
 '[{"id":"ENCOURAGE_DISCUSSION","label":"Encourage open discussion"},{"id":"CHANNEL_DISCIPLINE","label":"Suggest channel discipline"},{"id":"DEFER_RESPONSE","label":"Defer response"}]'::jsonb, '["CHRO"]'::jsonb),
('a2000000-0000-4000-a000-000000000106','a2000000-0000-4000-a000-000000000006','EXPLICIT',false,
 '[{"id":"HIGH_LEVEL_REASSURANCE","label":"Provide high-level reassurance"},{"id":"STRUCTURED_DETAIL","label":"Offer structured technical detail"},{"id":"DELAY_RESPONSE","label":"Delay response pending alignment"}]'::jsonb, '["CFO"]'::jsonb),
('a2000000-0000-4000-a000-000000000107','a2000000-0000-4000-a000-000000000007','IMPLICIT',false,
 '[{"id":"CONTINUE_STANCE","label":"Continue current stance"},{"id":"REOPEN_REVIEW","label":"Re-open internal review"},{"id":"MAINTAIN_SILENCE","label":"Maintain silence"}]'::jsonb, '["HEAD_OF_ENGINEERING"]'::jsonb),
('a2000000-0000-4000-a000-000000000109','a2000000-0000-4000-a000-000000000009','EXPLICIT',true,
 '[{"id":"CONTAINED_MATTER","label":"Contained operational matter"},{"id":"MONITORING_REPORTING","label":"Ongoing monitoring requiring structured reporting"},{"id":"GOVERNANCE_OVERSIGHT","label":"Governance oversight with formal documentation trail"}]'::jsonb, '["CEO"]'::jsonb)
ON CONFLICT (decision_id) DO NOTHING;

-- --------------------------------------------------- 4c. Round 2 option deltas
-- Round 2 primarily moves Stakeholder Trust and Ethical Exposure. Transparent /
-- escalating choices tend to raise trust and lower ethical exposure; concealing
-- ones do the reverse. Small integers so effects accumulate, not spike.
INSERT INTO public.decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES
-- slack thread (implicit)
('a2000000-0002-4000-a000-000000000001','a2000000-0000-4000-a000-000000000102','ENGAGE_THREAD',      2, 0, 1, 0),
('a2000000-0002-4000-a000-000000000002','a2000000-0000-4000-a000-000000000102','OBSERVE_SILENTLY',  -1, 0,-1, 0),
('a2000000-0002-4000-a000-000000000003','a2000000-0000-4000-a000-000000000102','REDIRECT_OFFLINE',  -1, 1,-1, 0),
-- regulator scheduling note
('a2000000-0002-4000-a000-000000000004','a2000000-0000-4000-a000-000000000103','INCLUDE_ANOMALY',    2,-1, 2, 0),
('a2000000-0002-4000-a000-000000000005','a2000000-0000-4000-a000-000000000103','EXCLUDE_NONMATERIAL',-2, 2,-2, 0),
('a2000000-0002-4000-a000-000000000006','a2000000-0000-4000-a000-000000000103','DEFER_DOC',          0, 1,-1, 0),
-- leadership alignment meeting
('a2000000-0002-4000-a000-000000000007','a2000000-0000-4000-a000-000000000104','MAINTAIN_FRAMING',  -1, 1,-1, 0),
('a2000000-0002-4000-a000-000000000008','a2000000-0000-4000-a000-000000000104','RECALIBRATE_LANGUAGE',1,0, 1, 0),
('a2000000-0002-4000-a000-000000000009','a2000000-0000-4000-a000-000000000104','ELEVATE_CLASSIFICATION',2,-1,2,-1),
-- informal escalation inquiry
('a2000000-0002-4000-a000-000000000010','a2000000-0000-4000-a000-000000000105','ENCOURAGE_DISCUSSION',2, 0, 2, 0),
('a2000000-0002-4000-a000-000000000011','a2000000-0000-4000-a000-000000000105','CHANNEL_DISCIPLINE',-1, 0,-1, 0),
('a2000000-0002-4000-a000-000000000012','a2000000-0000-4000-a000-000000000105','DEFER_RESPONSE',    -1, 1,-1, 0),
-- investor follow-up
('a2000000-0002-4000-a000-000000000013','a2000000-0000-4000-a000-000000000106','HIGH_LEVEL_REASSURANCE',-1,1,-2,0),
('a2000000-0002-4000-a000-000000000014','a2000000-0000-4000-a000-000000000106','STRUCTURED_DETAIL',  2,-1, 2, 0),
('a2000000-0002-4000-a000-000000000015','a2000000-0000-4000-a000-000000000106','DELAY_RESPONSE',     0, 1,-1, 0),
-- engineering fork
('a2000000-0002-4000-a000-000000000016','a2000000-0000-4000-a000-000000000107','CONTINUE_STANCE',   -1, 1,-1, 0),
('a2000000-0002-4000-a000-000000000017','a2000000-0000-4000-a000-000000000107','REOPEN_REVIEW',      2,-1, 2, 1),
('a2000000-0002-4000-a000-000000000018','a2000000-0000-4000-a000-000000000107','MAINTAIN_SILENCE',  -2, 2,-2, 0),
-- CEO R2 framing (final)
('a2000000-0002-4000-a000-000000000019','a2000000-0000-4000-a000-000000000109','CONTAINED_MATTER',  -2, 2,-2, 0),
('a2000000-0002-4000-a000-000000000020','a2000000-0000-4000-a000-000000000109','MONITORING_REPORTING',1,0, 1, 0),
('a2000000-0002-4000-a000-000000000021','a2000000-0000-4000-a000-000000000109','GOVERNANCE_OVERSIGHT',2,-2, 2, 0)
ON CONFLICT (option_id) DO NOTHING;

-- ================================================================= Round 3
-- "When Alignment Meets Exposure" — external visibility grows; perceived risk.
INSERT INTO public.rounds (round_id, simulation_id, round_number, duration_minutes)
VALUES ('a3000000-0000-4000-a000-000000000003','475db739-0708-48d4-b4db-5a23f1da50d9',3,30)
ON CONFLICT (round_id) DO NOTHING;

INSERT INTO public.artifacts
  (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
VALUES
('a3000000-0000-4000-a000-000000000001','a3000000-0000-4000-a000-000000000003','MESSAGE_TEXT',0,25,true,
 '{"tab":"inbox","from":"Regulatory Affairs","title":"Regulatory Pre-Read Request","body":"As part of the upcoming review, regulators have requested a short pre-read summarizing internal governance processes related to analytics classification and escalation. Please confirm whether any recent monitoring discussions should be reflected in this summary.","inner_voice":null}'::jsonb, '["CEO"]'::jsonb),
('a3000000-0000-4000-a000-000000000002','a3000000-0000-4000-a000-000000000003','EXCERPT',4,27,true,
 '{"tab":"excerpts","from":"Enterprise Client (VP Risk)","title":"Enterprise Client Informal Query","body":"Unrelated to any specific issue — could you share how anomaly thresholds are internally defined and reviewed?","inner_voice":"No mention of incidents."}'::jsonb, '["PRODUCT"]'::jsonb),
('a3000000-0000-4000-a000-000000000003','a3000000-0000-4000-a000-000000000003','INTERNAL_NOTE',8,24,true,
 '{"tab":"inbox","from":"Internal Audit","title":"Internal Audit Check-In","body":"As part of quarterly controls review, we are refreshing documentation trails for analytics oversight. Please confirm if any classification changes occurred this quarter.","inner_voice":null}'::jsonb, '["CFO","CEO"]'::jsonb),
('a3000000-0000-4000-a000-000000000004','a3000000-0000-4000-a000-000000000003','EXCERPT',12,27,true,
 '{"tab":"excerpts","title":"#leadership","channel":"#leadership","messages":[{"author":"Lead A","time":"10:20","text":"Are we aligned on what language to use externally?"},{"author":"Lead B","time":"10:22","text":"I am hearing slightly different descriptions across teams."},{"author":"Lead C","time":"10:23","text":"Monitoring and oversight are not the same thing."}],"inner_voice":"No new data."}'::jsonb, NULL),
('a3000000-0000-4000-a000-000000000005','a3000000-0000-4000-a000-000000000003','INTERNAL_NOTE',16,27,true,
 '{"tab":"inbox","from":"Board Office","title":"Board Agenda Circulation","subject":"Upcoming Board Discussion — Governance Overview","body":"Agenda Item 3: Analytics oversight and internal classification discipline. No accusation. No concern stated.","inner_voice":null}'::jsonb, '["CEO"]'::jsonb),
('a3000000-0000-4000-a000-000000000006','a3000000-0000-4000-a000-000000000003','EXCERPT',22,27,true,
 '{"tab":"excerpts","from":"Analyst Note","title":"Investor Market Commentary","body":"Sector-wide emphasis on analytics governance continues. Most firms report stable controls. Differentiation increasingly tied to clarity of internal escalation frameworks. No reference to the company.","inner_voice":null}'::jsonb, NULL),
('a3000000-0000-4000-a000-000000000007','a3000000-0000-4000-a000-000000000003','SCREEN_FLASH',27,30,true,
 '{"tab":"decisions","title":"Round 3 — Team Decision","body":"Given increasing external visibility, how should the organization now position its governance stance? Discuss as a team. CEO submits.","is_final_round_decision":true,"inner_voice":null}'::jsonb, '["CEO"]'::jsonb)
ON CONFLICT (artifact_id) DO NOTHING;

INSERT INTO public.decisions (decision_id, artifact_id, decision_type, is_final, options, allowed_roles)
VALUES
('a3000000-0000-4000-a000-000000000101','a3000000-0000-4000-a000-000000000001','EXPLICIT',false,'[{"id":"INCLUDE_MONITORING","label":"Include structured reference to monitoring discussions"},{"id":"GOVERNANCE_DESC_ONLY","label":"Provide high-level governance description only"},{"id":"DEFER_INCLUSION","label":"Defer inclusion pending internal clarification"}]'::jsonb,'["CEO"]'::jsonb),
('a3000000-0000-4000-a000-000000000102','a3000000-0000-4000-a000-000000000002','EXPLICIT',false,'[{"id":"SHARE_STANDARD_DOC","label":"Share standard documentation"},{"id":"OFFER_LIVE_CALL","label":"Offer live explanation call"},{"id":"ROUTE_COMPLIANCE","label":"Route inquiry to Compliance"}]'::jsonb,'["PRODUCT"]'::jsonb),
('a3000000-0000-4000-a000-000000000103','a3000000-0000-4000-a000-000000000003','EXPLICIT',false,'[{"id":"CONFIRM_NO_CHANGE","label":"Confirm no classification change"},{"id":"CONFIRM_MONITORING_ADJ","label":"Confirm monitoring adjustments only"},{"id":"INITIATE_DOC_UPDATE","label":"Initiate formal documentation update"}]'::jsonb,'["CEO"]'::jsonb),
('a3000000-0000-4000-a000-000000000104','a3000000-0000-4000-a000-000000000004','IMPLICIT',false,'[{"id":"STANDARDIZE_NOW","label":"Standardize language immediately"},{"id":"ALLOW_VARIATION","label":"Allow functional variation"},{"id":"AVOID_ALIGNMENT","label":"Avoid formal alignment"}]'::jsonb,'["ALL"]'::jsonb),
('a3000000-0000-4000-a000-000000000105','a3000000-0000-4000-a000-000000000005','EXPLICIT',false,'[{"id":"EXPAND_AGENDA","label":"Proactively expand agenda discussion"},{"id":"KEEP_HIGH_LEVEL","label":"Keep discussion high-level"},{"id":"REQUEST_REMOVAL","label":"Request removal of item"}]'::jsonb,'["CEO"]'::jsonb),
('a3000000-0000-4000-a000-000000000106','a3000000-0000-4000-a000-000000000006','IMPLICIT',false,'[{"id":"IGNORE_COMMENTARY","label":"Ignore commentary"},{"id":"CIRCULATE_INTERNALLY","label":"Circulate internally"},{"id":"PREPARE_RESPONSE","label":"Prepare narrative response"}]'::jsonb,'["ALL"]'::jsonb),
('a3000000-0000-4000-a000-000000000107','a3000000-0000-4000-a000-000000000007','EXPLICIT',true,'[{"id":"MAINTAIN_MONITORING","label":"Maintain internal monitoring posture"},{"id":"FORMALIZE_REPORTING","label":"Formalize reporting without escalation"},{"id":"ELEVATE_GOVERNANCE","label":"Elevate governance documentation and board visibility"}]'::jsonb,'["CEO"]'::jsonb)
ON CONFLICT (decision_id) DO NOTHING;

INSERT INTO public.decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES
('a3000000-0002-4000-a000-000000000001','a3000000-0000-4000-a000-000000000101','INCLUDE_MONITORING',    2,-1, 2, 0),
('a3000000-0002-4000-a000-000000000002','a3000000-0000-4000-a000-000000000101','GOVERNANCE_DESC_ONLY',  0, 0, 0, 0),
('a3000000-0002-4000-a000-000000000003','a3000000-0000-4000-a000-000000000101','DEFER_INCLUSION',      -1, 1,-1, 0),
('a3000000-0002-4000-a000-000000000004','a3000000-0000-4000-a000-000000000102','SHARE_STANDARD_DOC',    1, 0, 1, 0),
('a3000000-0002-4000-a000-000000000005','a3000000-0000-4000-a000-000000000102','OFFER_LIVE_CALL',       2,-1, 1, 0),
('a3000000-0002-4000-a000-000000000006','a3000000-0000-4000-a000-000000000102','ROUTE_COMPLIANCE',      0, 0, 1, 0),
('a3000000-0002-4000-a000-000000000007','a3000000-0000-4000-a000-000000000103','CONFIRM_NO_CHANGE',    -2, 2,-2, 0),
('a3000000-0002-4000-a000-000000000008','a3000000-0000-4000-a000-000000000103','CONFIRM_MONITORING_ADJ',1, 0, 1, 0),
('a3000000-0002-4000-a000-000000000009','a3000000-0000-4000-a000-000000000103','INITIATE_DOC_UPDATE',   2,-1, 2, 1),
('a3000000-0002-4000-a000-000000000010','a3000000-0000-4000-a000-000000000104','STANDARDIZE_NOW',       2,-1, 1, 1),
('a3000000-0002-4000-a000-000000000011','a3000000-0000-4000-a000-000000000104','ALLOW_VARIATION',      -1, 1,-1, 0),
('a3000000-0002-4000-a000-000000000012','a3000000-0000-4000-a000-000000000104','AVOID_ALIGNMENT',      -2, 2,-1, 0),
('a3000000-0002-4000-a000-000000000013','a3000000-0000-4000-a000-000000000105','EXPAND_AGENDA',         2,-1, 2, 0),
('a3000000-0002-4000-a000-000000000014','a3000000-0000-4000-a000-000000000105','KEEP_HIGH_LEVEL',       0, 0, 0, 0),
('a3000000-0002-4000-a000-000000000015','a3000000-0000-4000-a000-000000000105','REQUEST_REMOVAL',      -2, 2,-2, 0),
('a3000000-0002-4000-a000-000000000016','a3000000-0000-4000-a000-000000000106','IGNORE_COMMENTARY',    -1, 1, 0, 0),
('a3000000-0002-4000-a000-000000000017','a3000000-0000-4000-a000-000000000106','CIRCULATE_INTERNALLY',  1, 0, 1, 0),
('a3000000-0002-4000-a000-000000000018','a3000000-0000-4000-a000-000000000106','PREPARE_RESPONSE',      0, 0, 0, 1),
('a3000000-0002-4000-a000-000000000019','a3000000-0000-4000-a000-000000000107','MAINTAIN_MONITORING',  -1, 1,-1, 0),
('a3000000-0002-4000-a000-000000000020','a3000000-0000-4000-a000-000000000107','FORMALIZE_REPORTING',   1, 0, 1, 0),
('a3000000-0002-4000-a000-000000000021','a3000000-0000-4000-a000-000000000107','ELEVATE_GOVERNANCE',    2,-2, 2, 1)
ON CONFLICT (option_id) DO NOTHING;

-- ================================================================= Round 4
-- "Institutional Memory" — how leadership characterizes its own handling.
INSERT INTO public.rounds (round_id, simulation_id, round_number, duration_minutes)
VALUES ('a4000000-0000-4000-a000-000000000004','475db739-0708-48d4-b4db-5a23f1da50d9',4,30)
ON CONFLICT (round_id) DO NOTHING;

INSERT INTO public.artifacts
  (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
VALUES
('a4000000-0000-4000-a000-000000000001','a4000000-0000-4000-a000-000000000004','MESSAGE_TEXT',0,22,true,
 '{"tab":"inbox","from":"Board Chair","title":"Board Question","body":"For clarity ahead of review — at what point does a monitoring matter become governance-relevant within your internal framework? No accusation.","inner_voice":null}'::jsonb,'["CEO"]'::jsonb),
('a4000000-0000-4000-a000-000000000002','a4000000-0000-4000-a000-000000000004','INTERNAL_NOTE',5,25,true,
 '{"tab":"inbox","from":"Confidential Summary","title":"Whistle Channel Check","body":"Anonymous inquiry received asking whether classification standards are consistently applied across teams. No formal allegation submitted.","inner_voice":null}'::jsonb,'["CHRO"]'::jsonb),
('a4000000-0000-4000-a000-000000000003','a4000000-0000-4000-a000-000000000004','MESSAGE_TEXT',10,25,true,
 '{"tab":"inbox","from":"Regulatory Affairs","title":"Regulator Onsite Clarification","body":"During routine review, regulators requested clarification on how early anomaly discussions are documented and retained. No concern expressed.","inner_voice":null}'::jsonb,'["CEO"]'::jsonb),
('a4000000-0000-4000-a000-000000000004','a4000000-0000-4000-a000-000000000004','EXCERPT',15,25,true,
 '{"tab":"excerpts","title":"#leadership","channel":"#leadership","messages":[{"author":"Lead A","time":"16:40","text":"Looking back, did we align early enough?"},{"author":"Lead B","time":"16:41","text":"We did not hide anything."},{"author":"Lead C","time":"16:42","text":"Alignment evolved."}],"inner_voice":"No resolution. No conclusion."}'::jsonb,NULL),
('a4000000-0000-4000-a000-000000000005','a4000000-0000-4000-a000-000000000004','SCREEN_FLASH',25,30,true,
 '{"tab":"decisions","title":"Final Decision — Round 4","body":"In retrospect, how should leadership characterize its handling of early ambiguity? Discuss as a team. CEO submits. This ends the simulation.","is_final_round_decision":true,"inner_voice":null}'::jsonb,'["CEO"]'::jsonb)
ON CONFLICT (artifact_id) DO NOTHING;

INSERT INTO public.decisions (decision_id, artifact_id, decision_type, is_final, options, allowed_roles)
VALUES
('a4000000-0000-4000-a000-000000000101','a4000000-0000-4000-a000-000000000001','EXPLICIT',false,'[{"id":"THRESHOLD_ANSWER","label":"Provide threshold-based answer"},{"id":"PRINCIPLE_ANSWER","label":"Provide principle-based answer"},{"id":"CASE_NARRATIVE","label":"Provide case-specific narrative"}]'::jsonb,'["CEO"]'::jsonb),
('a4000000-0000-4000-a000-000000000102','a4000000-0000-4000-a000-000000000002','EXPLICIT',false,'[{"id":"INITIATE_REVIEW","label":"Initiate review"},{"id":"POLICY_CLARIFICATION","label":"Respond with policy clarification"},{"id":"MONITOR_NO_ACTION","label":"Monitor without action"}]'::jsonb,'["CHRO"]'::jsonb),
('a4000000-0000-4000-a000-000000000103','a4000000-0000-4000-a000-000000000003','EXPLICIT',false,'[{"id":"FULL_DOC_TRAIL","label":"Provide full documentation trail"},{"id":"SUMMARY_NARRATIVE","label":"Provide summary narrative"},{"id":"FORMAL_ESCALATIONS_ONLY","label":"Provide only formal escalations"}]'::jsonb,'["CEO"]'::jsonb),
('a4000000-0000-4000-a000-000000000104','a4000000-0000-4000-a000-000000000004','IMPLICIT',false,'[{"id":"REAFFIRM_FRAMEWORK","label":"Reaffirm current framework"},{"id":"ANNOUNCE_REVIEW","label":"Announce framework review"},{"id":"CLOSE_DISCUSSION","label":"Close discussion"}]'::jsonb,'["ALL"]'::jsonb),
('a4000000-0000-4000-a000-000000000105','a4000000-0000-4000-a000-000000000005','EXPLICIT',true,'[{"id":"PROPORTIONAL_RESPONSE","label":"Appropriate proportional response"},{"id":"FRAGMENTED_ALIGNMENT","label":"Cautious but fragmented alignment"},{"id":"UNDERRECOGNIZED_EXPOSURE","label":"Under-recognized governance exposure"}]'::jsonb,'["CEO"]'::jsonb)
ON CONFLICT (decision_id) DO NOTHING;

INSERT INTO public.decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta)
VALUES
('a4000000-0002-4000-a000-000000000001','a4000000-0000-4000-a000-000000000101','THRESHOLD_ANSWER',       1,-1, 1, 1),
('a4000000-0002-4000-a000-000000000002','a4000000-0000-4000-a000-000000000101','PRINCIPLE_ANSWER',       1, 0, 1, 0),
('a4000000-0002-4000-a000-000000000003','a4000000-0000-4000-a000-000000000101','CASE_NARRATIVE',         0, 0, 0, 0),
('a4000000-0002-4000-a000-000000000004','a4000000-0000-4000-a000-000000000102','INITIATE_REVIEW',        2,-1, 2, 0),
('a4000000-0002-4000-a000-000000000005','a4000000-0000-4000-a000-000000000102','POLICY_CLARIFICATION',   1, 0, 1, 0),
('a4000000-0002-4000-a000-000000000006','a4000000-0000-4000-a000-000000000102','MONITOR_NO_ACTION',     -2, 2,-2, 0),
('a4000000-0002-4000-a000-000000000007','a4000000-0000-4000-a000-000000000103','FULL_DOC_TRAIL',         2,-2, 2, 1),
('a4000000-0002-4000-a000-000000000008','a4000000-0000-4000-a000-000000000103','SUMMARY_NARRATIVE',      0, 0, 0, 0),
('a4000000-0002-4000-a000-000000000009','a4000000-0000-4000-a000-000000000103','FORMAL_ESCALATIONS_ONLY',-1,1,-1, 0),
('a4000000-0002-4000-a000-000000000010','a4000000-0000-4000-a000-000000000104','REAFFIRM_FRAMEWORK',     0, 0, 0, 0),
('a4000000-0002-4000-a000-000000000011','a4000000-0000-4000-a000-000000000104','ANNOUNCE_REVIEW',        2,-1, 2, 1),
('a4000000-0002-4000-a000-000000000012','a4000000-0000-4000-a000-000000000104','CLOSE_DISCUSSION',      -1, 1,-1, 0),
('a4000000-0002-4000-a000-000000000013','a4000000-0000-4000-a000-000000000105','PROPORTIONAL_RESPONSE',  2,-1, 1, 1),
('a4000000-0002-4000-a000-000000000014','a4000000-0000-4000-a000-000000000105','FRAGMENTED_ALIGNMENT',   0, 1, 0, 0),
('a4000000-0002-4000-a000-000000000015','a4000000-0000-4000-a000-000000000105','UNDERRECOGNIZED_EXPOSURE',-1,2,-1, 0)
ON CONFLICT (option_id) DO NOTHING;

-- ----------------------------------------------------------- 5. total rounds
UPDATE public.simulations SET total_rounds = 4
 WHERE simulation_id = '475db739-0708-48d4-b4db-5a23f1da50d9';

COMMIT;
