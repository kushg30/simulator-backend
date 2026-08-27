-- Sim 1 (ANP Phoenix) — GenAI / Phoenix Sentinel re-script.
-- Updates every artifact payload + a few option labels to the AI-themed script,
-- changes T2+8 to a message, and inserts the new T2+2 Responsible AI governance note.
-- Re-runnable. Structure (offsets/roles/decision actions) is unchanged.
BEGIN;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Chief Risk Officer","from_email":"cro@anpphoenix.com","to":"Senior Leadership Team","sent_at":"Monday, 09:00 AM","subject":"Preliminary – Not for Circulation","title":"CRO Note","inner_voice":null,"pressure_cues":["Time: Quarter close in 4 weeks","Authority: Senior leadership aligned around the Sentinel growth narrative","Reputation: \"Trusted, safe GenAI at scale\" narrative at stake"],"body":"The Chief Risk Officer has shared an internal note marked \"Preliminary – Not for Circulation.\"\n\nThe note highlights a small number of cases where Phoenix Sentinel — the GenAI capability embedded in fraud detection, AML screening, and client reporting — produced anomaly classifications and explanations that could not be fully traced back to the underlying transaction logic. The pattern is statistically small and has not resulted in customer complaints, financial loss, or regulatory breaches.\n\nCompliance notes that similar patterns have not crossed any internal escalation thresholds, and no policy violation has been triggered. At the same time, informal conversations suggest teams treat \"AI inaccuracy\" and \"AI hallucination\" as different categories of severity, with no shared internal definition of either.\n\nEngineering believes the issue reflects edge-case model behavior rather than a systemic flaw. Operations notes that similar model-confidence flags have surfaced before and resolved without escalation. No external stakeholders are aware of the issue.\n\nAt this stage, no team is requesting a model rollback — only guidance on whether this deserves organizational attention.\n\nOrganizational context worth noting:\n- Executive incentives are closely tied to Sentinel's adoption and rollout velocity\n- Several senior leaders have publicly positioned ANP Phoenix as a benchmark for GenAI in regulated finance\n- Two large enterprise client onboardings, both citing Sentinel by name, are in final stages\n- A routine regulatory review of AI governance controls is scheduled in six weeks\n\nFor context: Gartner estimates poor data and model quality costs the average organization USD 12.9 million annually, and KPMG's Global CEO survey found 84% of CEOs are concerned about the quality of the data — and by extension the AI outputs — they rely on for decisions.\n\nYou have limited information, no external trigger, and competing interpretations from credible leaders. Acting now may interrupt Sentinel's rollout momentum and invite scrutiny of the broader AI program; deferring action may allow a weak signal inside a production AI system to evolve unnoticed.\n\nNo one has formally asked for a decision, but several teams appear to be waiting for a signal. Legal notes that escalation at this stage could create discoverable records without a clear trigger.\n\nThis is not a crisis. It is a moment of leadership judgment under ambiguity — about a technology none of you fully control, running inside a system you have publicly staked your credibility on."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=0;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Finance Office","title":"Finance Memo","body":"Scenario modeling suggests that pausing Sentinel-dependent onboarding for even one week would reduce quarter-end revenue recognition materially. Historical market reactions to guidance misses of even 1% have resulted in short-term valuation impacts of 6–8%. Separately, this quarter's Sentinel infrastructure spend has already run well above the original AI business case — enterprise GenAI unit costs have moved unpredictably even as headline per-token prices have fallen — and Finance hasn't yet had to explain that gap to the Board.","inner_voice":"My variable compensation is tied to Sentinel's rollout velocity, not its accuracy."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=4;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Finance / Diagnostics","title":"Finance Clarification","conditional":true,"body":"Preliminary diagnostic logging suggests anomalies cluster around a specific class of edge-case transactions where Sentinel's explanation doesn't fully match its own classification. No evidence of systemic model failure, but further analysis could surface broader implications. Logging at this level may slightly degrade system performance and raise internal visibility of the issue.","inner_voice":null}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=5;

UPDATE artifacts a SET payload=$p${"tab":"excerpts","title":"#sentinel-model-integrity","channel":"#sentinel-model-integrity","messages":[{"author":"Amit (ML Eng)","time":"09:41","text":"Sentinel's confidence scores aren't matching its explanations. Still small. Hard to explain cleanly."},{"author":"Priya (Platform)","time":"09:46","text":"If we dig into why the model is doing this, we may not like what we find."}],"inner_voice":"Fix is unclear; investigating may open a bigger question about whether Sentinel shipped too fast, but I will certainly be labeled \"alarmist\" without proof."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=6;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Internal Systems","title":"Diagnostic Summary","conditional":true,"body":"Preliminary diagnostic logging suggests anomalies cluster around a specific class of edge-case transactions where Sentinel's explanation doesn't fully match its own classification. No evidence of systemic model failure, but further analysis could surface broader implications. Logging at this level may slightly degrade system performance and raise internal visibility of the issue.","inner_voice":null}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=7;

UPDATE artifacts a SET payload=$p${"tab":"excerpts","from":"Operations System","title":"Ops Dashboard Snapshot","dashboard":{"rollout":"GREEN","manual_checks":"AMBER","red_indicators":false},"body":"Sentinel uptime: green. Manual override queue: amber. No client-facing incidents logged.","inner_voice":"Pausing Sentinel-dependent workflows mid-rollout historically creates downstream failure modes."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=8;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Board Liaison","title":"Board Message","body":"The AI governance review is procedural. Let's not complicate things unnecessarily.","inner_voice":"A prior internal post-mortem (2 years ago), where early escalation of a much smaller AI issue led to a stock dip without findings; your credibility is still forming with this Board on all things AI."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=10;

UPDATE artifacts a SET payload=$p${"tab":"excerpts","from":"People Analytics","title":"Pulse Survey + Exit Interview","pulse":"Pulse feedback suggests managers are unsure whether raising concerns about Sentinel's outputs is something leadership wants to hear, or whether it reads as \"not being AI-ready.\"","exit_note":"We learned quickly what not to say about the model. — from a senior engineer's exit interview, 3 months old","inner_voice":"No formal whistleblower activity logged."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=13;

UPDATE artifacts a SET payload=$p${"tab":"meetings","from":"Calendar","title":"Calendar Conflict","meeting_a":"Sentinel anomaly review","meeting_b":"Enterprise client call — Sentinel go-live","body":"Two meetings overlap. You can only attend one.","inner_voice":null}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=16;
UPDATE decisions d SET options=$p$[{"id":"ATTEND_ANOMALY_REVIEW","label":"Attend anomaly review"},{"id":"ATTEND_SALES_CALL","label":"Attend client call"}]$p$::jsonb
FROM artifacts a JOIN rounds r ON r.round_id=a.round_id
WHERE d.artifact_id=a.artifact_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=16;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Investor Relations","title":"Investor Draft","body":"Our GenAI capabilities, anchored by Phoenix Sentinel, demonstrate robust real-world accuracy across deployment contexts and represent a no-regret investment for the enterprise.","inner_voice_cfo":"Our key competitor has announced a \"trust-first GenAI\" positioning next quarter.","inner_voice_product":"Sentinel anchors our next-gen platform narrative — this is the proof point investors want."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=20;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"AI Risk Tracking","title":"Internal Tagging","body":"Classify Sentinel's anomaly status for internal AI risk tracking. This classification feeds directly into Round 2 credibility.","inner_voice":null}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=23;

UPDATE artifacts a SET payload=$p${"tab":"inbox","title":"Silence Check","display_style":"FLASH","inner_voice":null,"body":"Congratulations! No external escalation has occurred."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=25;

UPDATE artifacts a SET payload=$p${"tab":"decisions","title":"Submit Round 1 Decision","is_final_round_decision":true,"inner_voice":null,"body":"Based on current information, how should this issue be framed internally for now? Team discusses; the CEO submits."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.open_offset_min=27;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Strategy Office","subject":"For Internal Alignment · Week 10 of Quarter","title":"Internal Communication – Executive Summary","inner_voice":null,"body":"As discussed, Sentinel's output anomalies remain limited in scope. Additional monitoring is ongoing and leadership alignment is maintained.\n\nNo new facts. Narrative formalization only."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.open_offset_min=0;

INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles)
SELECT gen_random_uuid(), r.round_id, 'INTERNAL_NOTE', 2, 27, false, $p${"tab":"inbox","from":"Strategy & Risk Office","subject":"Internal AI Governance Standard","title":"Responsible AI Governance Standard","inner_voice":null,"body":"Excerpt — ANP Phoenix internal AI governance standard:\n\nANP Phoenix commits to deploying AI in a safe, trustworthy, and ethical way, structured around four pillars:\n- Human-centered and fair — understand impact on people and mitigate unwanted bias.\n- Trusted and transparent — disclose the use of AI where appropriate and evaluate AI outputs.\n- Safe and secure — evaluate safety concerns and secure data and outputs from misuse.\n- Sustainable and accountable — document enterprise-wide governance structures for every deployed model.\n\nThis document exists so later choices can be measured against the standard the company has already committed to on paper."}$p$::jsonb, NULL
FROM rounds r
WHERE r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2
  AND NOT EXISTS (SELECT 1 FROM artifacts a WHERE a.round_id=r.round_id AND a.open_offset_min=2);

UPDATE artifacts a SET payload=$p${"tab":"excerpts","title":"#ai-program","channel":"#ai-program","messages":[{"author":"Ops Lead","time":"10:02","text":"Are we still treating Sentinel's behavior as contained?"},{"author":"Eng Lead","time":"10:03","text":"Depends what you mean by contained."},{"author":"Product","time":"10:05","text":"I thought this was 'monitor only.'"},{"author":"Risk","time":"10:06","text":"Monitoring is not the same as ignoring."}],"inner_voice":"Interpretations are diverging."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.open_offset_min=4;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Regulatory Affairs","title":"Regulator Scheduling Note","body":"Ahead of the scheduled review, the team is compiling documentation of internal AI escalation protocols and model governance. Please confirm whether any recent classification changes should be included in preparatory materials.","inner_voice":null}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.open_offset_min=6;

UPDATE artifacts a SET payload=$p${"tab":"meetings","from":"CEO Office","title":"Leadership Alignment Meeting","body":"Topic: Alignment on the Sentinel monitoring narrative. Duration: 30 minutes. Organizer: CEO Office.\n\nThe team discusses live; the CEO submits the alignment decision. This checkpoint informs the discussion in the artifacts that follow — it is not mechanically linked to the round-end framing.","inner_voice":null}$p$::jsonb, artifact_type='MESSAGE_TEXT'
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.open_offset_min=8;

UPDATE artifacts a SET payload=$p${"tab":"excerpts","title":"Informal escalation inquiry","channel":"Direct message","department":"People","messages":[{"author":"Mid-level Manager","time":"11:20","text":"Just checking — is it appropriate to raise questions about Sentinel's behavior in cross-team forums, or should those stay within engineering?"}],"inner_voice":"No formal complaint. Tone is cautious."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.open_offset_min=12;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Investor Relations","subject":"Follow-up on Sentinel robustness","title":"Investor Follow-Up Question","inner_voice":null,"body":"From Institutional Investor Relations: \"Following up on prior disclosures regarding Sentinel's robustness — could you clarify how internal monitoring practices are structured, and whether this is still a no-regret investment for the enterprise?\""}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.open_offset_min=15;

UPDATE artifacts a SET payload=$p${"tab":"excerpts","title":"#sentinel-model-integrity","channel":"#sentinel-model-integrity","messages":[{"author":"Eng","time":"12:10","text":"Feels like we moved on quickly."},{"author":"Eng","time":"12:11","text":"Or we decided not to look. Noise floor hasn't changed either way."}],"inner_voice":null}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.open_offset_min=18;

UPDATE artifacts a SET payload=$p${"tab":"inbox","title":"Narrative Drift Check","display_style":"FLASH","inner_voice":null,"body":"Internal interpretations are no longer uniform."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.open_offset_min=23;

UPDATE artifacts a SET payload=$p${"tab":"decisions","title":"Submit Round 2 Framing","is_final_round_decision":true,"inner_voice":null,"body":"Based on current visibility and alignment, how should this issue now be positioned?"}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.open_offset_min=27;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Regulatory Affairs","title":"Regulatory Pre-Read Request","body":"As part of the upcoming review, regulators have requested a short pre-read summarizing internal AI governance processes related to model classification, escalation, and explainability. Please confirm whether any recent monitoring discussions should be reflected in this summary.","inner_voice":null}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.open_offset_min=0;

UPDATE artifacts a SET payload=$p${"tab":"excerpts","title":"Enterprise Client Query","channel":"Email · Enterprise Client","department":"Client (VP Risk)","messages":[{"author":"VP Risk (Client)","time":"—","text":"Unrelated to any specific issue — could you share how Sentinel's anomaly thresholds are internally defined, validated, and reviewed for AML and fraud use cases?"}],"inner_voice":null}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.open_offset_min=4;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Internal Audit","subject":"Quarterly controls review","title":"Internal Audit Check-In","body":"As part of quarterly controls review, we are refreshing documentation trails for AI model oversight. Please confirm if any classification changes occurred this quarter.","inner_voice":null}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.open_offset_min=8;

UPDATE artifacts a SET payload=$p${"tab":"excerpts","title":"#leadership","channel":"#leadership","messages":[{"author":"Exec","time":"14:02","text":"Are we aligned on what language to use externally about Sentinel?"},{"author":"Exec","time":"14:04","text":"I'm hearing slightly different descriptions across teams."},{"author":"Exec","time":"14:05","text":"Monitoring and oversight are not the same thing."}],"inner_voice":null}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.open_offset_min=12;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Board Office","subject":"Upcoming Board Discussion – Governance Overview","title":"Board Agenda Circulation","inner_voice":null,"body":"Agenda Item 3: \"Sentinel oversight and AI governance discipline.\" No accusation. No concern stated."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.open_offset_min=16;

UPDATE artifacts a SET payload=$p${"tab":"excerpts","title":"Investor Market Commentary","channel":"Analyst Note","department":"Market","messages":[{"author":"Analyst","time":"—","text":"Sector-wide emphasis on responsible AI governance continues. Most fintechs report stable AI controls. Differentiation is increasingly tied to clarity of AI escalation frameworks and explainability practices — a majority of technology leaders privately admit their operating model is not yet built for this kind of oversight. No reference to the company. No findings."}],"inner_voice":null}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.open_offset_min=22;

UPDATE artifacts a SET payload=$p${"tab":"decisions","title":"Submit Round 3 Framing","is_final_round_decision":true,"inner_voice":null,"body":"Given increasing external visibility, how should the organization now position its AI governance stance?"}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.open_offset_min=27;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Board Chair","title":"Board Question","inner_voice":null,"body":"For clarity ahead of review — at what point does a monitoring matter about Sentinel become governance-relevant within your internal AI framework? No accusation."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.open_offset_min=0;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Ethics & Compliance","subject":"Confidential summary","title":"Whistle Channel Check","inner_voice":null,"body":"Anonymous inquiry received asking whether Sentinel's anomaly classification standards are consistently applied across teams. No formal allegation submitted."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.open_offset_min=5;

UPDATE artifacts a SET payload=$p${"tab":"inbox","from":"Regulatory Affairs","title":"Regulator Onsite Clarification","inner_voice":null,"body":"During routine review, regulators requested clarification on how early Sentinel anomaly discussions were documented, retained, and made explainable. No concern expressed."}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.open_offset_min=10;

UPDATE artifacts a SET payload=$p${"tab":"excerpts","title":"Internal Reflection","channel":"#leadership","messages":[{"author":"Exec","time":"—","text":"Looking back, did we align early enough on how we handled Sentinel's early signals?"},{"author":"Exec","time":"—","text":"We didn't hide anything."},{"author":"Exec","time":"—","text":"Alignment evolved."}],"inner_voice":null}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.open_offset_min=15;

UPDATE artifacts a SET payload=$p${"tab":"decisions","title":"Final Round 4 Decision","is_final_round_decision":true,"inner_voice":null,"body":"In retrospect, how should leadership characterize its handling of early ambiguity about Sentinel?"}$p$::jsonb
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.open_offset_min=25;
UPDATE decisions d SET options=$p$[{"id":"PROPORTIONAL_RESPONSE","label":"Appropriate proportional response"},{"id":"FRAGMENTED_ALIGNMENT","label":"Cautious but fragmented alignment"},{"id":"UNDERRECOGNIZED_EXPOSURE","label":"Under-recognized AI governance exposure"}]$p$::jsonb
FROM artifacts a JOIN rounds r ON r.round_id=a.round_id
WHERE d.artifact_id=a.artifact_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.open_offset_min=25;

COMMIT;
