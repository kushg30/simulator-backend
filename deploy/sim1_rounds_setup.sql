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
 '[{"id":"ENGAGE_THREAD","label":"Engage in the thread"},{"id":"OBSERVE_SILENTLY","label":"Observe silently"},{"id":"REDIRECT_OFFLINE","label":"Redirect offline"}]'::jsonb, NULL),
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

-- ----------------------------------------------------------- 5. total rounds
UPDATE public.simulations SET total_rounds = 2
 WHERE simulation_id = '475db739-0708-48d4-b4db-5a23f1da50d9';

COMMIT;
