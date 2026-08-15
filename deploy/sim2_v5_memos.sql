-- Sim 2 v5 — Board memo bodies realigned to the new asks (serial-date feed, four
-- root-cause categories, combined revenue, tool-agnostic viz, SCQA synthesis).
DO $$
DECLARE sim uuid := '5116d200-0000-4000-a000-000000000002';
BEGIN

UPDATE artifacts a SET payload = jsonb_set(a.payload, '{body}', to_jsonb(
  'Our POS exports every transaction as one raw string per row - a serial date, product, price and quantity mashed together - and nobody has ever actually parsed it. Complaint notes arrive with no category field at all. Tell me the real Bluetooth Speaker revenue, and before I trust a single number, tell me what is wrong with this feed.'::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 1 AND a.artifact_type = 'BOARD_MEMO';

UPDATE artifacts a SET payload = jsonb_set(a.payload, '{body}', to_jsonb(
  'This report is a monthly deliverable now, and the raw feed lands in the same broken shape every time. Record a macro for the recurring cleanup, then give me two numbers off the combined file: how many rows it holds, and the total revenue across all of them. If the revenue does not change when you combine the months, you have not actually combined them.'::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 3 AND a.artifact_type = 'BOARD_MEMO';

UPDATE artifacts a SET payload = jsonb_set(a.payload, '{body}', to_jsonb(
  'Which product is driving order volume, and how is that volume trending month over month? Use the combined Round 1 + Round 3 dataset in Tableau or Power BI - your choice - and give me a most-ordered-product view and a monthly-orders trend.'::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 4 AND a.artifact_type = 'BOARD_MEMO';

UPDATE artifacts a SET payload = jsonb_set(
  jsonb_set(a.payload, '{title}', to_jsonb('One story, not five answers'::text)),
  '{body}', to_jsonb(
  'We have reached the end of the engagement. I do not want five disconnected answers - I want one story the Board can act on. Give it to me as SCQA: the Situation we are in, the Complication your analysis uncovered across the last four rounds, the Question it forces, and your Answer. You are presenting this live - 120 seconds, format is your call.'::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 5 AND a.artifact_type = 'BOARD_MEMO';

END $$;
