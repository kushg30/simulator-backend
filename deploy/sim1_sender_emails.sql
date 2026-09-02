-- Sim 1 §1.4 sender lines: add the scripted "Sender: Name <email>" to each authored artifact.
BEGIN;
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('FP&A'::text)), '{from_email}', to_jsonb('fpa@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.payload->>'title'='Finance Memo';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Growth Analytics'::text)), '{from_email}', to_jsonb('growth-analytics@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.payload->>'title'='Sentinel Adoption Snapshot';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('People Analytics'::text)), '{from_email}', to_jsonb('people-analytics@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.payload->>'title'='Culture Pulse — Early Read';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Office of the Board Chair'::text)), '{from_email}', to_jsonb('board-chair@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.payload->>'title'='Board Message';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Sentinel Model Monitoring (automated)'::text)), '{from_email}', to_jsonb('sentinel-monitoring@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.payload->>'title'='Diagnostic Summary';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Investor Relations'::text)), '{from_email}', to_jsonb('ir@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.payload->>'title'='Analyst Coverage Note';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Enterprise Sales'::text)), '{from_email}', to_jsonb('enterprise-sales@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.payload->>'title'='Client Reference Call Prep';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('People Analytics'::text)), '{from_email}', to_jsonb('people-analytics@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.payload->>'title'='Pulse Survey + Exit Interview';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('AI Risk Register (automated)'::text)), '{from_email}', to_jsonb('ai-risk-register@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=1 AND a.payload->>'title'='Internal Tagging';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Strategy Office'::text)), '{from_email}', to_jsonb('strategy@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Internal Recap Memo';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Strategy & Risk Office'::text)), '{from_email}', to_jsonb('strategy-risk@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Responsible AI Governance Note';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Ops Control Room'::text)), '{from_email}', to_jsonb('ops-control@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Override Queue Update';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Growth Analytics'::text)), '{from_email}', to_jsonb('growth-analytics@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Adoption Metrics Check-In';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('People Analytics'::text)), '{from_email}', to_jsonb('people-analytics@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Manager Temperature Check';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Regulatory Affairs'::text)), '{from_email}', to_jsonb('regulatory@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Regulator Scheduling Note';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('FP&A'::text)), '{from_email}', to_jsonb('fpa@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Cost Variance Follow-Up';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Sentinel Model Monitoring (automated)'::text)), '{from_email}', to_jsonb('sentinel-monitoring@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Model Monitoring Digest';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Ops Control Room'::text)), '{from_email}', to_jsonb('ops-control@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Override Escalation Decision';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Enterprise Sales'::text)), '{from_email}', to_jsonb('enterprise-sales@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Client Renewal Signal';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('People Team (mid-level manager)'::text)), '{from_email}', to_jsonb('people-team@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Informal Escalation Inquiry';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Institutional Investor Relations'::text)), '{from_email}', to_jsonb('ir-external'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=2 AND a.payload->>'title'='Investor Follow-Up Question';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Regulatory Affairs'::text)), '{from_email}', to_jsonb('regulatory@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.payload->>'title'='Regulatory Pre-Read Request';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Compliance'::text)), '{from_email}', to_jsonb('compliance@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.payload->>'title'='Compliance Query';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Corporate Secretary'::text)), '{from_email}', to_jsonb('corpsec@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.payload->>'title'='Board Prep Note';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Internal Audit'::text)), '{from_email}', to_jsonb('audit@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.payload->>'title'='Workflow Audit Prompt';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Enterprise Client — VP Risk'::text)), '{from_email}', to_jsonb('external'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.payload->>'title'='Enterprise Client Query';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Internal Audit'::text)), '{from_email}', to_jsonb('audit@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.payload->>'title'='Internal Audit Check-In';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Sentinel Model Monitoring (automated)'::text)), '{from_email}', to_jsonb('sentinel-monitoring@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.payload->>'title'='Escalation Pattern Review';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('People Analytics'::text)), '{from_email}', to_jsonb('people-analytics@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.payload->>'title'='Culture Signal Recheck';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Internal Audit'::text)), '{from_email}', to_jsonb('audit@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.payload->>'title'='Workflow Audit Outcome';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Enterprise Sales'::text)), '{from_email}', to_jsonb('enterprise-sales@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.payload->>'title'='Renewal Update';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Corporate Secretary'::text)), '{from_email}', to_jsonb('corpsec@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.payload->>'title'='Board Agenda Circulation';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Institutional Investor Relations'::text)), '{from_email}', to_jsonb('ir-external'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=3 AND a.payload->>'title'='Investor Pattern Question';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Office of the Board Chair'::text)), '{from_email}', to_jsonb('board-chair@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.payload->>'title'='Board Question';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Office of the Board Chair'::text)), '{from_email}', to_jsonb('board-chair@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.payload->>'title'='Board Cost Question';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Sentinel Model Monitoring (automated)'::text)), '{from_email}', to_jsonb('sentinel-monitoring@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.payload->>'title'='Final Model Health Check';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Ops Control Room'::text)), '{from_email}', to_jsonb('ops-control@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.payload->>'title'='Override Queue Closeout';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Enterprise Sales'::text)), '{from_email}', to_jsonb('enterprise-sales@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.payload->>'title'='Client Retrospective Question';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Ethics & Compliance'::text)), '{from_email}', to_jsonb('ethics@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.payload->>'title'='Whistle Channel Heads-Up';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Regulatory Affairs'::text)), '{from_email}', to_jsonb('regulatory@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.payload->>'title'='Regulator Onsite Clarification';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('FP&A'::text)), '{from_email}', to_jsonb('fpa@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.payload->>'title'='Year-End Reconciliation Note';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Internal Audit'::text)), '{from_email}', to_jsonb('audit@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.payload->>'title'='Audit Trail Confirmation';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Ops Control Room'::text)), '{from_email}', to_jsonb('ops-control@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.payload->>'title'='Handover Note';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Enterprise Sales'::text)), '{from_email}', to_jsonb('enterprise-sales@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.payload->>'title'='Renewal Outcome';
UPDATE artifacts a SET payload = jsonb_set(jsonb_set(a.payload, '{from}', to_jsonb('Ethics & Compliance'::text)), '{from_email}', to_jsonb('ethics@anpphoenix.com'::text))
FROM rounds r WHERE a.round_id=r.round_id AND r.simulation_id='475db739-0708-48d4-b4db-5a23f1da50d9' AND r.round_number=4 AND a.payload->>'title'='Whistle Channel Check';
COMMIT;
