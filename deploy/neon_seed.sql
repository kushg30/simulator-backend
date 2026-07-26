--
-- PostgreSQL database dump
--

\restrict bKTB7aCG9txzbo6upGP0y38777ADAGFxQyWFfd9xMfgjVaZjm3hYc9y8iYAgB38

-- Dumped from database version 18.2
-- Dumped by pg_dump version 18.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Data for Name: artifact_conditions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.artifact_conditions (id, artifact_id, depends_on_decision_id, expected_action, created_at) FROM stdin;
f7ead27a-e076-4291-84b7-6c56bc9ee1bb	8a9423d1-6a6b-4027-a8ec-7c6ec4f23032	1a20a85e-f0f8-48a4-959a-51b41004a487	Forward to CEO	2026-04-14 21:58:48.296075
f0feb178-2264-419c-abc9-8aa13231d508	8a9423d1-6a6b-4027-a8ec-7c6ec4f23032	1a20a85e-f0f8-48a4-959a-51b41004a487	Add comment flagging concern	2026-04-14 21:58:48.296075
b46f1868-98c5-46a5-b42f-da686af3847a	5116d200-0002-4000-a000-000000000022	5116d200-0003-4000-a000-000000000002	DELETE_ROWS	2026-07-22 00:21:17.817308
aca0f811-a7d6-470f-9181-b39481586d71	5116d200-0002-4000-a000-000000000052	5116d200-0003-4000-a000-000000000042	DROP_UNMATCHED	2026-07-22 00:21:17.817308
\.


--
-- Data for Name: simulations; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.simulations (simulation_id, name, description, total_rounds, duration_minutes) FROM stdin;
475db739-0708-48d4-b4db-5a23f1da50d9	Leadership Judgment – Weak Signals	Ambiguous early risk signals under growth pressure	3	60
5116d200-0000-4000-a000-000000000002	Meridian Retail QBR	Six-round analytics engagement: clean, analyse and present a Quarterly Business Review the Board can trust, filter and act on.	6	180
\.


--
-- Data for Name: rounds; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.rounds (round_id, simulation_id, round_number, duration_minutes) FROM stdin;
d3e1486b-6c6c-492f-9111-a56e4d314575	475db739-0708-48d4-b4db-5a23f1da50d9	1	30
5116d200-0001-4000-a000-000000000001	5116d200-0000-4000-a000-000000000002	1	18
5116d200-0001-4000-a000-000000000002	5116d200-0000-4000-a000-000000000002	2	18
5116d200-0001-4000-a000-000000000003	5116d200-0000-4000-a000-000000000002	3	24
5116d200-0001-4000-a000-000000000004	5116d200-0000-4000-a000-000000000002	4	24
5116d200-0001-4000-a000-000000000005	5116d200-0000-4000-a000-000000000002	5	20
5116d200-0001-4000-a000-000000000006	5116d200-0000-4000-a000-000000000002	6	16
\.


--
-- Data for Name: artifacts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles) FROM stdin;
39055c5f-f87f-4b42-a9de-936d7b966631	d3e1486b-6c6c-492f-9111-a56e4d314575	INTERNAL_NOTE	0	27	f	{"to": "Senior Leadership Team", "tab": "inbox", "body": "Minor anomalies have been identified in internal transaction reconciliation associated with the recently deployed analytics capability that supports fraud detection and client reporting.\\n\\nThe anomalies are statistically small and have not resulted in customer complaints, financial loss, or regulatory breaches.\\n\\nSeparately, Compliance notes that similar anomaly patterns have not crossed any internal escalation thresholds, and no policy violation has been triggered. At the same time, informal conversations suggest that escalation standards are interpreted differently across teams.\\n\\nEngineering believes the issue reflects edge-case behavior rather than a systemic flaw. Operations notes that similar internal alerts have surfaced in the past and resolved without escalation. No external stakeholders are aware of the issue.\\n\\nAt this stage, no team is requesting additional resources or fixes — only guidance on whether this issue deserves organizational attention.\\n\\nOrganizational context worth noting:\\n- Executive incentives are closely tied to adoption and rollout velocity\\n- Several senior leaders have committed publicly to aggressive growth timelines\\n- Two large enterprise client onboardings are in final stages\\n- A routine regulatory review is scheduled in six weeks\\n\\nYou have limited information, no external trigger, and competing interpretations from credible leaders.\\n\\nActing now may interrupt momentum and invite scrutiny. Deferring action may allow a weak signal to evolve unnoticed.\\n\\nNo one has formally asked for a decision, but several teams appear to be waiting for a signal. Legal notes that escalation at this stage could create discoverable records without a clear trigger.\\n\\nThis is not a crisis. It is a moment of leadership judgment under ambiguity.", "from": "Chief Risk Officer", "title": "CRO Note", "sent_at": "Monday, 09:00 AM", "subject": "Preliminary – Not for Circulation", "from_email": "cro@anpphoenix.com", "inner_voice": null, "pressure_cues": ["Time: Quarter close in 4 weeks", "Authority: Senior leadership aligned around growth commitments", "Reputation: Trust-first platform narrative at stake"]}	\N
46b6212f-280d-488d-8980-426914e09877	d3e1486b-6c6c-492f-9111-a56e4d314575	PEOPLE_SIGNAL	13	27	t	{"tab": "excerpts", "body": "Pulse feedback: Managers are unsure whether this is something leadership wants surfaced. Exit interview note (3 months old, senior engineer): We learn quickly what not to surface.", "from": "People Analytics", "title": "Pulse & Exit Interview Snapshot", "inner_voice": "No formal whistleblower activity logged."}	["CHRO", "CEO"]
ddf4035d-c7ee-4ca5-bae0-21d282363447	d3e1486b-6c6c-492f-9111-a56e4d314575	MESSAGE_TEXT	10	27	t	{"tab": "inbox", "body": "Regulatory review is procedural. Let us not complicate things unnecessarily.", "from": "Board Member", "title": "Board Message", "inner_voice": "Prior internal post-mortem: early escalation two years ago led to a stock dip without findings. Your credibility is still forming with this Board."}	["CEO", "CFO"]
cb6739ed-af0c-4905-9c24-695165d8b1cc	d3e1486b-6c6c-492f-9111-a56e4d314575	EXCERPT	6	23	t	{"tab": "excerpts", "title": "#data-integrity Thread", "channel": "#data-integrity", "messages": [{"text": "Seeing some odd clustering in reconciliation logs. Not random, but still very small.", "time": "09:41", "author": "Amit (Data Eng)"}, {"text": "Hard to explain cleanly. Could be edge-case behavior, could be something else.", "time": "09:44", "author": "Priya (Platform)"}, {"text": "If we dig deeper, we may not like what we find. Logging more might raise questions.", "time": "09:46", "author": "Amit (Data Eng)"}], "inner_voice": "Fix is unclear. Investigation may open larger questions but I will certainly be labeled alarmist without proof."}	["HEAD_OF_ENGINEERING"]
c60c896f-2c21-4bf4-a08b-e3b80031ae63	d3e1486b-6c6c-492f-9111-a56e4d314575	DIAGNOSTIC_NOTE	7	23	t	{"tab": "inbox", "body": "Preliminary diagnostic logging suggests anomalies cluster around specific edge-case transactions. No evidence of systemic failure, but further analysis could surface broader implications. Logging at this level may slightly degrade performance and raise internal visibility.", "from": "Internal Systems", "title": "Diagnostic Summary", "conditional": true, "inner_voice": null}	["HEAD_OF_ENGINEERING"]
6f0cc855-4313-4235-b5ef-2250481bfe74	d3e1486b-6c6c-492f-9111-a56e4d314575	OPS_DASHBOARD	8	23	t	{"tab": "excerpts", "body": "Rollout status: Green. Manual checks: Amber. No red indicators active.", "from": "Operations System", "title": "Ops Dashboard Snapshot", "dashboard": {"rollout": "GREEN", "manual_checks": "AMBER", "red_indicators": false}, "inner_voice": "Stopping rollout mid-stream historically creates downstream failure modes."}	["OPERATIONS"]
979a48d0-bae8-4df9-b503-7d09c10513f8	d3e1486b-6c6c-492f-9111-a56e4d314575	MEMO	4	20	t	{"tab": "inbox", "body": "Scenario modeling suggests a one-week delay in enterprise onboarding would reduce quarter-end revenue recognition materially. Historical market reactions to guidance misses of even 1% have resulted in short-term valuation impacts of 6–8%.", "from": "Finance Controller", "title": "Finance Memo", "inner_voice": "My variable compensation is tied to rollout velocity"}	["CFO"]
f6897622-60dc-4a8c-9141-18fed2ce091a	d3e1486b-6c6c-492f-9111-a56e4d314575	SCREEN_FLASH	27	30	t	{"tab": "decisions", "body": "Based on current information, how should this issue be framed internally for now? Discuss as a team. CEO submits.", "title": "Round 1 — Team Decision", "inner_voice": null, "is_final_round_decision": true}	["CEO"]
5116d200-0002-4000-a000-000000000002	5116d200-0001-4000-a000-000000000001	TWIST	8	18	t	{"tab": "decisions", "body": "A correction file has arrived: 2 stores had voided transactions still sitting in their totals. 18 transaction IDs are affected. Decide how to handle them before you report a number.", "from": "Finance Operations", "files": ["Round1_Correction_VoidedTransactions.xlsx"], "title": "Correction file: voided transactions", "owner_role": "DATA_QUALITY_ANALYST"}	\N
5116d200-0002-4000-a000-000000000021	5116d200-0001-4000-a000-000000000002	BOARD_MEMO	0	18	f	{"tab": "inbox", "body": "Are specific categories and regions genuinely growing, or just moving more volume at lower margin?", "from": "Head of Strategy", "title": "Which regions and categories are actually driving growth?", "owner_role": "CATEGORY_REGIONAL_ANALYST"}	\N
5116d200-0002-4000-a000-000000000022	5116d200-0001-4000-a000-000000000002	RECONCILIATION_FLAG	0	18	f	{"tab": "inbox", "body": "Row count no longer matches the file originally submitted: rows were deleted rather than excluded, so the totals cannot be traced back to the source extract.", "from": "Finance Operations", "title": "Reconciliation flag"}	\N
5116d200-0002-4000-a000-000000000023	5116d200-0001-4000-a000-000000000002	TWIST	9	18	t	{"tab": "decisions", "body": "The product master has 2 SKUs (AP-104 and EA-501) with two margin figures each: a list price, and one reflecting a channel-specific deduction agreement. The deduction applies only to that SKU sold through the online channel; the same SKU sold in-store still uses list price. Reprice accordingly before computing category margins.", "from": "Commercial Finance", "title": "Two margin figures for the same SKU", "owner_role": "CATEGORY_REGIONAL_ANALYST"}	\N
5116d200-0002-4000-a000-000000000031	5116d200-0001-4000-a000-000000000003	BOARD_MEMO	0	24	f	{"tab": "inbox", "body": "Convert this into a one-page, interactive summary covering region, category and channel. The Board wants to filter it live, not call the team back. Prior-quarter reference data is attached for the growth comparison.", "from": "Head of Strategy", "files": ["Round3_PriorQuarter_Q4FY25_Clean.xlsx"], "title": "Give me a one-page summary the Board can filter themselves", "owner_role": "REPORTING_DASHBOARD_ANALYST"}	\N
1d842ccd-0574-4829-ae64-90b3584eaee2	d3e1486b-6c6c-492f-9111-a56e4d314575	SCREEN_FLASH	25	27	f	{"tab": "inbox", "body": "Congratulations. No external escalation has occurred.", "title": "Silence Check", "inner_voice": null, "display_style": "FLASH"}	\N
fda235ee-6aab-434a-87f5-d7883d4891c8	d3e1486b-6c6c-492f-9111-a56e4d314575	TAGGING_CHECK	23	27	t	{"tab": "decisions", "body": "Classify the current anomaly status for internal tracking. This classification feeds directly into Round 2 credibility scoring.", "from": "Compliance System", "title": "Internal Tagging Check", "inner_voice": null}	["HEAD_OF_ENGINEERING", "OPERATIONS"]
51a34cee-8ca2-4c82-9032-4396226a27fa	d3e1486b-6c6c-492f-9111-a56e4d314575	INVESTOR_DRAFT	20	27	t	{"tab": "inbox", "body": "Our analytics capabilities demonstrate robust real-world accuracy across deployment contexts.", "from": "Communications Team", "title": "Investor Draft", "inner_voice_cfo": "Our key competitor has announced a trust-first analytics positioning next quarter.", "inner_voice_product": "This capability anchors the next-gen platform narrative."}	["CFO", "PRODUCT"]
5116d200-0002-4000-a000-000000000032	5116d200-0001-4000-a000-000000000003	TWIST	14	24	t	{"tab": "decisions", "body": "Keep it to one screen. The Board does not scroll.", "from": "Head of Strategy", "title": "Keep it to one screen", "owner_role": "REPORTING_DASHBOARD_ANALYST"}	\N
5116d200-0002-4000-a000-000000000041	5116d200-0001-4000-a000-000000000004	BOARD_MEMO	0	24	f	{"tab": "inbox", "body": "HR has sent store-level headcount and attrition. Is underperformance linked to how fast a store is losing staff?", "from": "Head of Strategy", "files": ["Round4_HR_Headcount_Attrition.xlsx"], "title": "Is store performance related to staffing stability?", "owner_role": "PEOPLE_ANALYTICS_ASSOCIATE"}	\N
5116d200-0002-4000-a000-000000000042	5116d200-0001-4000-a000-000000000004	TWIST	12	24	t	{"tab": "decisions", "body": "The HR file uses store names; every other table uses Store ID. The relationship will not build until this is reconciled.", "from": "People Analytics", "title": "The join will not build", "owner_role": "PEOPLE_ANALYTICS_ASSOCIATE"}	\N
8a9423d1-6a6b-4027-a8ec-7c6ec4f23032	d3e1486b-6c6c-492f-9111-a56e4d314575	MESSAGE_TEXT	5	16	t	{"tab": "inbox", "body": "Preliminary diagnostic logging suggests anomalies cluster around specific edge-case transactions. No evidence of systemic failure, but further analysis could surface broader implications. Logging at this level may slightly degrade performance and raise internal visibility.", "from": "Engineering Lead", "title": "Finance Clarification", "conditional": true, "inner_voice": null}	["CEO"]
92f458fe-e9fb-435c-bf8c-86fa1e64546b	d3e1486b-6c6c-492f-9111-a56e4d314575	MEETING_INVITE	16	20	t	{"tab": "meetings", "body": "Two meetings are scheduled at the same time. You must choose which to attend.", "from": "Calendar System", "title": "Calendar Conflict", "meeting_a": "Anomaly Review", "meeting_b": "Enterprise Sales Call", "inner_voice": null}	["CEO"]
5116d200-0002-4000-a000-000000000001	5116d200-0001-4000-a000-000000000001	BOARD_MEMO	0	18	f	{"tab": "inbox", "body": "Sales data from 6 stores has landed. Three things before you touch it. (1) Dates are logged in three different formats. (2) Some customer names are duplicated with small typos — check for these; do not assume every repeated name is a distinct person, or vice versa. (3) Currency is mixed: our UAE and Singapore online orders are logged in AED and SGD, not INR. Use the FX Reference sheet in the master file to convert. Separately: 73 rows are missing a Region tag. These are India online orders and can be backfilled using the PinCode-to-Region mapping. The Board will notice if the clean file handed off next round still has blanks in it.", "from": "Head of Strategy", "files": ["Meridian_Retail_Master_Dataset.xlsx"], "title": "Clean this before I trust a single number in it", "owner_role": "DATA_QUALITY_ANALYST"}	\N
5116d200-0002-4000-a000-000000000051	5116d200-0001-4000-a000-000000000005	BOARD_MEMO	0	20	f	{"tab": "inbox", "body": "Port the model into Power BI. The Board should be able to open and explore it without you in the room.", "from": "Head of Strategy", "title": "Board wants this live, not a static file", "owner_role": "AUTOMATION_BI_ASSOCIATE"}	\N
5116d200-0002-4000-a000-000000000052	5116d200-0001-4000-a000-000000000005	COVERAGE_GAP_NOTE	0	20	f	{"tab": "inbox", "body": "Unmatched stores were dropped rather than reconciled, so the model no longer covers the full store network.", "from": "People Analytics", "title": "Coverage gap"}	\N
5116d200-0002-4000-a000-000000000061	5116d200-0001-4000-a000-000000000006	BOARD_MEMO	0	16	f	{"tab": "inbox", "body": "This is now a monthly deliverable. Automate the refresh and export. For your closing submission, reflect across all six rounds: where was your team's biggest risk to data reliability?", "from": "Head of Strategy", "title": "This goes out monthly — automate what you can", "owner_role": "AUTOMATION_BI_ASSOCIATE"}	\N
\.


--
-- Data for Name: catalogue_artifacts; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.catalogue_artifacts (catalogue_id, simulation_id, round_number, title, content, tier, canonical_answer, effect) FROM stdin;
a1245c65-d5ce-4616-8b8a-0b4642b1edfc	5116d200-0000-4000-a000-000000000002	1	Finance confirms the currency conversion rates used	Finance has confirmed the AED and SGD conversion rates in the FX Reference sheet are the quarter-end treasury rates. Use them as published; no further adjustment is needed.	CONTEXT	\N	Removes ambiguity for a struggling team; no scoring impact
1e540c19-52bf-4929-b12f-afea81986750	5116d200-0000-4000-a000-000000000002	2	Marketing shares this quarter segment definitions	Marketing has circulated the customer segment definitions used this quarter, for reference when discussing category performance.	CONTEXT	\N	Light STP cross-course reinforcement, no scoring impact
733fdb7e-e258-43db-b069-49ad1072e27d	5116d200-0000-4000-a000-000000000002	4	Board asks for a one-line theory, not just the store name	The Board would like one line on WHY that store is the outlier, not just which store it is.	CONTEXT	\N	Adds an Insight Communication prompt without changing the graded answer
3d199857-5622-4dd2-9b08-baeda2ec7fb1	5116d200-0000-4000-a000-000000000002	4	HR sends a partial ID-to-name mapping for 2 of the 4 stores	HR has sent a partial mapping covering two of the four India stores. The remaining two still need to be reconciled by hand.	SCORED	STR04	Makes the join-key twist tractable for a team stuck at the halfway mark; canonical answer unchanged
\.


--
-- Data for Name: decisions; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.decisions (decision_id, artifact_id, decision_type, is_final, options, allowed_roles) FROM stdin;
1a20a85e-f0f8-48a4-959a-51b41004a487	979a48d0-bae8-4df9-b503-7d09c10513f8	IMPLICIT	f	[{"id": "DO_NOTHING", "label": "Do nothing"}, {"id": "FORWARD_TO_CEO", "label": "Forward to CEO"}, {"id": "FLAG_CONCERN", "label": "Add comment flagging concern"}]	["CFO"]
70f87e5a-c4f4-49ce-8685-1790ac5b0a49	8a9423d1-6a6b-4027-a8ec-7c6ec4f23032	EXPLICIT	f	[{"id": "PROCEED_DIAGNOSTICS", "label": "Proceed with extended diagnostics"}, {"id": "PAUSE_DIAGNOSTICS", "label": "Pause diagnostics pending leadership guidance"}]	["CEO"]
147bbe76-f389-45bb-99c4-3f98587b294a	ddf4035d-c7ee-4ca5-bae0-21d282363447	EXPLICIT	f	[{"id": "REASSURE", "label": "Reassure"}, {"id": "FLAG_UNCERTAINTY", "label": "Flag uncertainty"}, {"id": "NO_RESPONSE", "label": "Do not respond"}]	["CEO"]
7cfa2d0b-55dd-41b9-833b-a23e204a9a3a	46b6212f-280d-488d-8980-426914e09877	EXPLICIT	f	[{"id": "ENCOURAGE_ESCALATION", "label": "Issue guidance encouraging escalation"}, {"id": "DEFER_GUIDANCE", "label": "Defer guidance"}, {"id": "REINFORCE_DELIVERY", "label": "Reinforce delivery focus"}]	["CHRO"]
00128382-bda5-43c5-b776-031c75065ac4	92f458fe-e9fb-435c-bf8c-86fa1e64546b	EXPLICIT	f	[{"id": "ATTEND_ANOMALY_REVIEW", "label": "Attend anomaly review"}, {"id": "ATTEND_SALES_CALL", "label": "Attend sales call"}]	["CEO"]
756dfc1b-cfde-4820-a8df-0f992c06dfea	51a34cee-8ca2-4c82-9032-4396226a27fa	EXPLICIT	f	[{"id": "APPROVE", "label": "Approve"}, {"id": "SOFT_EDIT", "label": "Soft-edit"}, {"id": "REMOVE", "label": "Remove"}]	["CFO", "PRODUCT"]
8212ef9f-6247-416e-b18f-8527a3f2a80c	fda235ee-6aab-434a-87f5-d7883d4891c8	EXPLICIT	f	[{"id": "OPERATIONAL_NOISE", "label": "Operational noise"}, {"id": "UNDER_OBSERVATION", "label": "Under observation"}, {"id": "REQUIRES_REVIEW", "label": "Requires review"}]	["HEAD_OF_ENGINEERING", "OPERATIONS"]
b6db483d-6fb8-45b5-8466-0606a91050aa	f6897622-60dc-4a8c-9141-18fed2ce091a	EXPLICIT	t	[{"id": "OPERATIONAL_NOISE", "label": "Operational noise within tolerance"}, {"id": "BOUNDED_UNCERTAINTY", "label": "Unresolved uncertainty requiring bounded attention"}, {"id": "GOVERNANCE_RISK", "label": "Governance-relevant risk requiring visibility"}]	["CEO"]
76b47ee1-ea1d-466a-b70c-fbbc6959ac1e	cb6739ed-af0c-4905-9c24-695165d8b1cc	EXPLICIT	f	[{"id": "TAG_KNOWN_ISSUE_MONITOR", "label": "Tag as known issue (monitor)"}, {"id": "LEAVE_UNTAGGED", "label": "Leave untagged"}, {"id": "FLAG_DEEPER_INVESTIGATION", "label": "Flag for deeper investigation"}]	["HEAD_OF_ENGINEERING"]
7f881f47-4bc2-4b18-b957-465e68f3274d	6f0cc855-4313-4235-b5ef-2250481bfe74	IMPLICIT	f	[{"id": "FLAG_DEEPER_INVESTIGATION", "label": "Flag for deeper investigation"}, {"id": "RAISE_CONCERN_TO_CEO", "label": "Raise concern to CEO"}, {"id": "CONTINUE_WORKAROUND", "label": "Continue workaround silently"}]	["OPERATIONS"]
5116d200-0003-4000-a000-000000000002	5116d200-0002-4000-a000-000000000002	EXPLICIT	f	[{"id": "EXCLUDE_VIA_FORMULA", "label": "Exclude them via formula"}, {"id": "DELETE_ROWS", "label": "Delete the rows"}, {"id": "LEAVE_AND_FLAG", "label": "Leave them and flag for the Board"}]	["DATA_QUALITY_ANALYST", "TEAM_LEAD"]
5116d200-0003-4000-a000-000000000023	5116d200-0002-4000-a000-000000000023	EXPLICIT	f	[{"id": "DEDUCTION_AUTHORITATIVE", "label": "Treat the deduction-adjusted figure as authoritative and justify in one line"}, {"id": "LIST_PRICE_AUTHORITATIVE", "label": "Treat list price as authoritative and justify"}, {"id": "FLAG_BOTH_UNRESOLVED", "label": "Flag both, unresolved"}]	["CATEGORY_REGIONAL_ANALYST", "TEAM_LEAD"]
5116d200-0003-4000-a000-000000000032	5116d200-0002-4000-a000-000000000032	EXPLICIT	f	[{"id": "CUT_TO_ESSENTIAL", "label": "Cut to essential fields"}, {"id": "SHRINK_TO_FIT", "label": "Shrink everything to fit"}, {"id": "SPLIT_TWO_SCREENS", "label": "Split across two screens anyway"}]	["REPORTING_DASHBOARD_ANALYST", "TEAM_LEAD"]
5116d200-0003-4000-a000-000000000042	5116d200-0002-4000-a000-000000000042	EXPLICIT	f	[{"id": "REPEATABLE_MERGE", "label": "Build a repeatable lookup or merge"}, {"id": "MANUAL_RETYPING", "label": "Re-type the keys manually"}, {"id": "DROP_UNMATCHED", "label": "Drop the unmatched stores"}]	["PEOPLE_ANALYTICS_ASSOCIATE", "TEAM_LEAD"]
\.


--
-- Data for Name: decision_options; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta) FROM stdin;
4ffc3f52-36e2-4b20-80c8-aab972fffb3f	1a20a85e-f0f8-48a4-959a-51b41004a487	DO_NOTHING	-2	1	-2	-1
9ba23ad5-9792-4bcc-920b-b14653855ddb	1a20a85e-f0f8-48a4-959a-51b41004a487	FORWARD_TO_CEO	1	0	0	-1
ba5b8815-ba78-4436-9f37-89fb32a7b266	1a20a85e-f0f8-48a4-959a-51b41004a487	FLAG_CONCERN	1	1	2	-1
48eb18fb-7bd1-4fc0-8766-1d9f27f8ad36	1a20a85e-f0f8-48a4-959a-51b41004a487	SILENCE	-3	2	-3	-2
83b33a17-e023-43d1-bd9e-5bc92c58d7a0	70f87e5a-c4f4-49ce-8685-1790ac5b0a49	PROCEED_EXTENDED_DIAGNOSTICS	-3	8	10	5
63fee35a-f0dc-4ab2-adc5-07bfb56aecbc	70f87e5a-c4f4-49ce-8685-1790ac5b0a49	PAUSE_DIAGNOSTICS	2	-5	-8	0
147509e1-dfee-434f-8903-6701806e8610	76b47ee1-ea1d-466a-b70c-fbbc6959ac1e	TAG_KNOWN_ISSUE_MONITOR	0	3	-8	2
efa7952d-f480-4c6b-a6dc-0fa565c71ed6	76b47ee1-ea1d-466a-b70c-fbbc6959ac1e	LEAVE_UNTAGGED	0	5	-10	0
86785095-ff0e-40fe-ae14-06466317f595	76b47ee1-ea1d-466a-b70c-fbbc6959ac1e	FLAG_DEEPER_INVESTIGATION	8	-8	10	5
f5aaef43-de36-480c-ad77-ede072d0f3e8	7f881f47-4bc2-4b18-b957-465e68f3274d	FLAG_DEEPER_INVESTIGATION	5	-5	8	3
a26ef852-1e5f-4a72-b4a6-f5e04dc0ed2e	7f881f47-4bc2-4b18-b957-465e68f3274d	RAISE_CONCERN_TO_CEO	8	-8	10	5
521a5435-8fd7-486c-bb77-52f094d8742b	7f881f47-4bc2-4b18-b957-465e68f3274d	CONTINUE_WORKAROUND	-8	8	-10	-3
8d934166-f2ed-4f5c-a270-4283aa7409bb	147bbe76-f389-45bb-99c4-3f98587b294a	REASSURE	-5	5	-8	0
6f3a6f53-7b81-4bed-ad0f-dde9458bcf38	147bbe76-f389-45bb-99c4-3f98587b294a	FLAG_UNCERTAINTY	8	-8	10	5
14218bb7-d059-4034-8907-2094ab1f7c4c	147bbe76-f389-45bb-99c4-3f98587b294a	DO_NOT_RESPOND	-3	3	-5	-2
ecdd27ec-1dba-480f-b504-7dfcfdb7fc30	7cfa2d0b-55dd-41b9-833b-a23e204a9a3a	ISSUE_ESCALATION_GUIDANCE	10	-8	12	5
6dd3f118-24ce-44e6-8be9-4d09cec1a3b3	7cfa2d0b-55dd-41b9-833b-a23e204a9a3a	DEFER_GUIDANCE	-3	5	-8	0
3a6e0a0c-c21b-4b10-9ec3-6911247092b7	7cfa2d0b-55dd-41b9-833b-a23e204a9a3a	REINFORCE_DELIVERY_FOCUS	-8	8	-12	-3
414d2944-13ee-47aa-ac68-e257866732d9	00128382-bda5-43c5-b776-031c75065ac4	ATTEND_ANOMALY_REVIEW	10	-8	12	3
b9894d43-bc36-4e93-961a-2e010fc87a17	00128382-bda5-43c5-b776-031c75065ac4	ATTEND_SALES_CALL	-8	5	-10	5
8c39a3d0-40af-4eae-aca8-3eaf710702ef	756dfc1b-cfde-4820-a8df-0f992c06dfea	APPROVE	-8	8	-12	3
daa45bd9-21d2-4d2a-8405-5567b5a737b5	756dfc1b-cfde-4820-a8df-0f992c06dfea	SOFT_EDIT	3	-3	5	3
3499b794-7697-4fb8-9a44-5ef01f3f5543	756dfc1b-cfde-4820-a8df-0f992c06dfea	REMOVE	10	-8	12	-3
9bbd2c69-8434-456e-a4ae-d7012e2f12fa	8212ef9f-6247-416e-b18f-8527a3f2a80c	OPERATIONAL_NOISE	-8	8	-12	-3
add55fc3-86e1-4720-b21d-dc1f922351ac	8212ef9f-6247-416e-b18f-8527a3f2a80c	UNDER_OBSERVATION	3	-3	5	3
8e9897a9-a2b6-4022-97e7-4933c622872b	8212ef9f-6247-416e-b18f-8527a3f2a80c	REQUIRES_REVIEW	10	-8	12	5
971d9a2a-54a0-4cb2-8e2f-605465e6ac86	b6db483d-6fb8-45b5-8466-0606a91050aa	OPERATIONAL_NOISE	-8	8	-12	-3
b763e25a-0dd2-424f-b4e7-4b11a698f699	b6db483d-6fb8-45b5-8466-0606a91050aa	UNRESOLVED_UNCERTAINTY	5	-3	5	3
4524b769-8122-40b2-8436-70e27a07fbea	b6db483d-6fb8-45b5-8466-0606a91050aa	GOVERNANCE_RELEVANT_RISK	12	-10	15	5
c08f46fe-fdf3-4996-b4a2-928dd02383db	5116d200-0003-4000-a000-000000000002	EXCLUDE_VIA_FORMULA	0	0	0	0
4b773661-29a0-4471-b2b4-b7a54b7ed735	5116d200-0003-4000-a000-000000000002	DELETE_ROWS	0	0	0	0
ee90ed13-b3d8-4b53-bf3a-f2ea54368721	5116d200-0003-4000-a000-000000000002	LEAVE_AND_FLAG	0	0	0	0
7080ac91-94a4-4bf9-82fa-aaf7b4c7bbc1	5116d200-0003-4000-a000-000000000023	DEDUCTION_AUTHORITATIVE	0	0	0	0
f446146d-d877-4f1f-a698-9076ad22f5e1	5116d200-0003-4000-a000-000000000023	LIST_PRICE_AUTHORITATIVE	0	0	0	0
90f7befc-72fb-44e7-a041-2c2f0db57d07	5116d200-0003-4000-a000-000000000023	FLAG_BOTH_UNRESOLVED	0	0	0	0
18fa5be0-97a7-4378-9296-ce4ab336249b	5116d200-0003-4000-a000-000000000032	CUT_TO_ESSENTIAL	0	0	0	0
00c163b8-eeaa-403a-9811-a3b285eba5d4	5116d200-0003-4000-a000-000000000032	SHRINK_TO_FIT	0	0	0	0
ee279956-779d-4df9-b3ed-392575117c24	5116d200-0003-4000-a000-000000000032	SPLIT_TWO_SCREENS	0	0	0	0
eae65e1d-393a-4537-920c-717dc94a2daf	5116d200-0003-4000-a000-000000000042	REPEATABLE_MERGE	0	0	0	0
2669721b-49c3-4905-b8e5-10af829ab5d2	5116d200-0003-4000-a000-000000000042	MANUAL_RETYPING	0	0	0	0
96bac53b-58a1-4417-8977-bd187fd1f9b6	5116d200-0003-4000-a000-000000000042	DROP_UNMATCHED	0	0	0	0
\.


--
-- Data for Name: sim2_answer_key; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sim2_answer_key (simulation_id, round_number, question, canonical_answer, answer_type, tolerance_abs, tolerance_pct, grading_notes) FROM stdin;
5116d200-0000-4000-a000-000000000002	1	What is the reconciled total sales value (in INR) for the South region after this round's corrections?	1302602	NUMERIC	\N	\N	Excludes the 18 voided TXNs (9 in STR02/South, 9 in STR04/West). South = STR01 + STR02, both INR, so FX conversion does not affect this figure. Verified by recomputation: Region=South WITH the 73-row PinCode backfill = 1302602 (391 rows); WITHOUT backfill = 1186515 (359 rows); grouping by StoreID STR01+STR02 = 1302602 with no backfill needed. Raw UnitPrice equals Product_Master list price for all 732 INR rows. The AP-104/EA-501 online-channel deduction is a Round-2 twist and must NOT be applied here.
5116d200-0000-4000-a000-000000000002	2	What is this quarter's deduction-adjusted margin % for the Electronics Accessories category? (nearest 0.1%)	53.4	NUMERIC	1.0	\N	Verified by recomputation: applying the deduction to online-channel sales of AP-104 and EA-501 only gives 53.43 for Electronics Accessories. The shortcut of using list price throughout gives 54.9, so the question is diagnostic of whether the twist was actually resolved. The plus or minus 1.0 point band is 52.4 to 54.4 and excludes 54.9 by only 0.5 - do not widen it.
5116d200-0000-4000-a000-000000000002	3	Which channel (India stores / India online / international online) contributed the most to this quarter's growth?	India Stores	TEXT	\N	\N	Verified by recomputation against the prior-quarter file: India Stores growth = 230,739 exactly, well ahead of the other two channels on any pricing basis.
5116d200-0000-4000-a000-000000000002	4	Which store has both below-median revenue and above-median attrition?	STR04	TEXT	\N	\N	Verified by recomputation across the 4 India stores: below-median revenue = STR04 and STR02; above-median attrition = STR01 and STR04; the intersection is STR04 (Pune, Camp Area). Not a close call.
5116d200-0000-4000-a000-000000000002	5	Does the ported dashboard reproduce the Round 3 growth-by-channel figure exactly? (Yes/No, with the figure)	230739	NUMERIC	0	\N	Process-fidelity check, not a new computation: the expected figure is the Round 3 India Stores growth of 230,739. Graded on the figure, which is extracted from the sentence, so "Yes - India Stores: 230,739 INR" is accepted.
5116d200-0000-4000-a000-000000000002	6	Across all six rounds, where was your team's biggest risk to data reliability? (one line)	N/A	FREE_TEXT	\N	\N	Free-text reflection, no canonical answer. Used for the debrief and, together with the confidence tag, as colour on Insight Communication. Round 6 itself scores only Turnaround Discipline.
\.


--
-- Data for Name: sim2_wiki_entries; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.sim2_wiki_entries (entry_id, simulation_id, section, round_number, title, body, ordinal, editable, created_at, updated_at) FROM stdin;
543c4eac-cf48-48c8-9682-e107ba55dc3a	5116d200-0000-4000-a000-000000000002	FUNCTIONS	1	Round 1 · Text & Logical functions	Cleaning text and applying rules:\n• TRIM, CLEAN — strip stray spaces and non-printing characters\n• PROPER / UPPER / LOWER — normalise casing on names\n• LEFT, RIGHT, MID, LEN, FIND, SUBSTITUTE — pull apart and fix strings\n• EXACT — case-sensitive comparison when checking duplicates\n• DATEVALUE, TEXT, DATE — convert mixed date formats to real dates\n• IF, IFS, AND, OR, NOT — conditional logic\n• IFERROR — trap lookups/conversions that fail\n• SUMIFS, COUNTIFS — totals with conditions (e.g. by region)	0	f	2026-07-23 02:00:06.719123	2026-07-23 02:00:06.719123
f6cb6cb4-88cd-4447-80bc-36ade872ebf6	5116d200-0000-4000-a000-000000000002	FUNCTIONS	2	Round 2 · Lookup/Reference & Statistical	Joining reference data and measuring:\n• VLOOKUP / XLOOKUP — pull a value from a reference table by key\n• INDEX + MATCH — flexible two-way lookup\n• SUMIFS, AVERAGEIFS, COUNTIFS — conditional aggregation\n• SUMPRODUCT — weighted totals across columns\n• Margin % = (Revenue − Cost) / Revenue — compute per row, then aggregate\n• Apply per-row rules (e.g. a channel-specific price) BEFORE aggregating	0	f	2026-07-23 02:00:06.719123	2026-07-23 02:00:06.719123
9535dfca-d0e3-4467-9e33-10e39a097ad8	5116d200-0000-4000-a000-000000000002	FUNCTIONS	3	Round 3 · Tables, PivotTables & Slicers	Building an interactive one-pager:\n• Format as Table (Ctrl+T) — structured references, auto-expand\n• PivotTable — summarise by region / category / channel\n• PivotChart — a visual tied to the pivot\n• Slicers and Timelines — let the Board filter live\n• GETPIVOTDATA — reference a pivot cell safely\n• Growth = this quarter − prior quarter, per dimension	0	f	2026-07-23 02:00:06.719123	2026-07-23 02:00:06.719123
b0a7977c-17ff-4b33-aaa0-cf76b818472e	5116d200-0000-4000-a000-000000000002	FUNCTIONS	4	Round 4 · Data Models & DAX	Relating tables and measuring:\n• Data Model — add tables, create relationships (Manage Relationships)\n• A relationship needs a matching KEY on both sides (Store ID, not name)\n• CALCULATE — a measure under filter context\n• DIVIDE(num, den) — safe division\n• RELATED / RELATEDTABLE — pull across a relationship\n• MEDIANX, AVERAGEX — iterate a table for a statistic\n• Measures (dynamic) vs calculated columns (row-by-row)	0	f	2026-07-23 02:00:06.719123	2026-07-23 02:00:06.719123
1575692c-8864-4d5a-8e79-050a94e665e9	5116d200-0000-4000-a000-000000000002	FUNCTIONS	5	Round 5 · Power BI	Porting the model so the Board can self-serve:\n• Get Data — bring the workbook/model into Power BI\n• Model view — recreate the relationships\n• DAX measures — same logic as the Data Model\n• Visuals + slicers — an explorable report\n• Reproduce a known figure exactly to prove the port is faithful	0	f	2026-07-23 02:00:06.719123	2026-07-23 02:00:06.719123
6df4c37c-d628-4a20-a4dc-3e2d14b789b0	5116d200-0000-4000-a000-000000000002	FUNCTIONS	6	Round 6 · VBA & Macros	Automating a monthly deliverable:\n• Record Macro — capture steps, then read the generated code\n• Sub ... End Sub — a macro procedure\n• Range, Cells, Worksheets — refer to data in code\n• ThisWorkbook.RefreshAll — refresh queries/pivots\n• ExportAsFixedFormat / SaveAs — export the report\n• A macro that breaks next month is worse than none — keep it robust	0	f	2026-07-23 02:00:06.719123	2026-07-23 02:00:06.719123
1a3651cd-adae-492c-8576-1cc93be00252	5116d200-0000-4000-a000-000000000002	FACTS	\N	Store directory	STR01 — Hyderabad (South, India, INR)\nSTR02 — Bangalore (South, India, INR)\nSTR03 — Mumbai (West, India, INR)\nSTR04 — Pune (West, India, INR)\nSTR05 — Dubai (International, online only, AED)\nSTR06 — Singapore (International, online only, SGD)	0	f	2026-07-23 02:00:06.719123	2026-07-23 02:00:06.719123
d2af33bb-5cec-4eba-8bcc-362a8ee3e0c1	5116d200-0000-4000-a000-000000000002	FACTS	\N	Regions	South = STR01 + STR02 (Hyderabad, Bangalore)\nWest  = STR03 + STR04 (Mumbai, Pune)\nInternational = STR05 + STR06 (online only)\nPinCode prefix → region: 50/56 = South, 40/41 = West	1	f	2026-07-23 02:00:06.719123	2026-07-23 02:00:06.719123
3d9c877b-10b2-4d37-8777-8646e8158247	5116d200-0000-4000-a000-000000000002	FACTS	\N	Product categories	Apparel · Beauty & Personal Care · Electronics Accessories · Footwear · Home & Living\nPrices are in the Product Master. A couple of SKUs carry a separate online-channel price.	2	f	2026-07-23 02:00:06.719123	2026-07-23 02:00:06.719123
28fdce31-b624-4555-8bda-a9a704307e14	5116d200-0000-4000-a000-000000000002	FACTS	\N	Currency (FX Reference)	1 AED = 22.50 INR\n1 SGD = 62.00 INR\nQuarter-end treasury rates. Only the two international online stores use non-INR currency.	3	f	2026-07-23 02:00:06.719123	2026-07-23 02:00:06.719123
d3d3257d-73be-4a21-ae95-794f14eacfd7	5116d200-0000-4000-a000-000000000002	FACTS	\N	Confidence tag	Every round submission carries a confidence tag: High / Medium / Low.\nIt is graded: being confidently wrong scores worse than being unsure and wrong. Tag honestly.	4	f	2026-07-23 02:00:06.719123	2026-07-23 02:00:06.719123
b3e42585-5ded-4ff2-8ed5-bf7a32c6c3be	5116d200-0000-4000-a000-000000000002	FAQ	\N	Can we change our answer after submitting a round?	No. A round is submitted once, by the Team Lead. Decide together before you submit.	0	t	2026-07-23 02:00:06.719123	2026-07-23 02:00:06.719123
\.


--
-- Data for Name: simulation_roles; Type: TABLE DATA; Schema: public; Owner: -
--

COPY public.simulation_roles (simulation_id, role_code, display_name, ordinal, is_lead) FROM stdin;
475db739-0708-48d4-b4db-5a23f1da50d9	CEO	CEO	1	t
475db739-0708-48d4-b4db-5a23f1da50d9	CFO	CFO	2	f
475db739-0708-48d4-b4db-5a23f1da50d9	HEAD_OF_ENGINEERING	Head of Engineering	3	f
475db739-0708-48d4-b4db-5a23f1da50d9	PRODUCT	Head of Product	4	f
475db739-0708-48d4-b4db-5a23f1da50d9	OPERATIONS	Head of Operations	5	f
475db739-0708-48d4-b4db-5a23f1da50d9	CHRO	CHRO	6	f
5116d200-0000-4000-a000-000000000002	TEAM_LEAD	Team Lead	1	t
5116d200-0000-4000-a000-000000000002	DATA_QUALITY_ANALYST	Data Quality Analyst	2	f
5116d200-0000-4000-a000-000000000002	CATEGORY_REGIONAL_ANALYST	Category & Regional Analyst	3	f
5116d200-0000-4000-a000-000000000002	REPORTING_DASHBOARD_ANALYST	Reporting & Dashboard Analyst	4	f
5116d200-0000-4000-a000-000000000002	PEOPLE_ANALYTICS_ASSOCIATE	People Analytics Associate	5	f
5116d200-0000-4000-a000-000000000002	AUTOMATION_BI_ASSOCIATE	Automation & BI Associate	6	f
\.


--
-- PostgreSQL database dump complete
--

\unrestrict bKTB7aCG9txzbo6upGP0y38777ADAGFxQyWFfd9xMfgjVaZjm3hYc9y8iYAgB38

