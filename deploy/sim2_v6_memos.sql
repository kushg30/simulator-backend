-- Sim 2 v6 — Board memos set VERBATIM from Meridian_QBR_Final_v6.docx.
DO $$
DECLARE sim uuid := '5116d200-0000-4000-a000-000000000002';
BEGIN

-- ── Round 1 memo ────────────────────────────────────────────────────────────
UPDATE artifacts a SET payload = jsonb_set(
  jsonb_set(a.payload, '{title}', to_jsonb('Before I say another number out loud, tell me if I can trust it'::text)),
  '{body}', to_jsonb($t$Here's what actually happened last quarter. I quoted a Bluetooth Speaker revenue number to the Board. Finance had a different number for the same product. Nobody could explain the gap, and I looked like I hadn't done my homework. That number came out of this feed, the one you're about to open.

Our Point of Sale (POS) system, the system that logs every transaction at checkout, exports each sale as one unreadable string. Nobody at Meridian has ever actually broken it apart to check it; every report so far has just trusted whatever the last export said. That's not a small problem. Industry research puts the average cost of poor data quality at close to 13 million dollars a year for a mid-size organization, mostly in decisions made on numbers nobody checked. I don't want to be a statistic.

I need one number I can actually defend in front of the Board: what did we make on Bluetooth Speaker. But before you give it to me, tell me what's actually wrong with this feed. If you can't tell me that, I have no reason to believe your number is any better than the one that got me in trouble last time. Split the work across your team. This shouldn't be a one person job.

Attached: Round1_RawFeed.xlsx$t$::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 1 AND a.artifact_type = 'BOARD_MEMO';

-- R1 mid-round twist
UPDATE artifacts a SET payload = jsonb_set(
  jsonb_set(a.payload, '{title}', to_jsonb('One more thing before you lock this'::text)),
  '{body}', to_jsonb($t$One more thing before you lock this. I've just heard some of these transactions might be logged twice somewhere in here. Check before you send me anything.$t$::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 1 AND a.artifact_type = 'SCREEN_FLASH';

-- ── Round 2 memo ────────────────────────────────────────────────────────────
UPDATE artifacts a SET payload = jsonb_set(
  jsonb_set(a.payload, '{title}', to_jsonb('Is this a people problem or something bigger'::text)),
  '{body}', to_jsonb($t$West region missed its quarterly attainment target by a wide margin, and I need to know why before I stand in front of the Board and guess. Revenue Attainment %, the actual revenue a store achieved as a percentage of its quarterly target, tells you how each store did against its own goal, not against the others. A store above 100% beat its target; a store below it fell short.

There are a few ways this kind of shortfall usually gets explained in a business like ours: a people and skills problem, a process and execution problem, a market condition nobody could have controlled, or a resource constraint like budget or staffing. I want you to tell me which one the data actually supports, not which one sounds the most comfortable to tell the Board. Use the store manager training dataset. Show me the number that convinced you.

Attached: Round2_StoreTraining.xlsx$t$::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 2 AND a.artifact_type = 'BOARD_MEMO';

-- R2 Emergency Board Call
UPDATE artifacts a SET payload = jsonb_set(a.payload, '{body}', to_jsonb(
  $t$Before we move on, how confident are you in what your team just submitted, really? One line.$t$::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 2 AND a.artifact_type = 'SCREEN_FLASH';

-- ── Round 3 memo ────────────────────────────────────────────────────────────
UPDATE artifacts a SET payload = jsonb_set(
  jsonb_set(a.payload, '{title}', to_jsonb('I need one clean file, not two'::text)),
  '{body}', to_jsonb($t$Finance needs last month combined with this month, structured the same way every time, because next quarter I'll ask you to do this again. Record a macro that does the combining so nobody has to rebuild it by hand every month. You already checked this data's quality in Round 1; I'm not asking you to do that again here. I just need one file, and I need to know your process actually produced it, not that you already knew the answer before you started.

Attached: Round3_NewMonth_RawFeed.xlsx$t$::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 3 AND a.artifact_type = 'BOARD_MEMO';

-- ── Round 4 memo ────────────────────────────────────────────────────────────
UPDATE artifacts a SET payload = jsonb_set(
  jsonb_set(a.payload, '{title}', to_jsonb('Show me, don''t tell me'::text)),
  '{body}', to_jsonb($t$The Board doesn't read spreadsheets. Build me two visuals: what we sell the most of, and when we sell the most of it. Use whichever tool you're more comfortable with, Tableau or Power BI; they're both built to do the same job here, so pick one and build something the Board could actually look at. If your team decides this dashboard is good enough to present as-is, it can become part of what you show the Board directly in the next stage.

Attached: the combined dataset from Round 3$t$::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 4 AND a.artifact_type = 'BOARD_MEMO';

-- ── Round 5 memo ────────────────────────────────────────────────────────────
UPDATE artifacts a SET payload = jsonb_set(
  jsonb_set(a.payload, '{title}', to_jsonb('This is what I''m walking into'::text)),
  '{body}', to_jsonb($t$I have a limited window with the Board, and they don't want to hear about raw strings or duplicate transactions. They want to know what happened, why it happened, and what we should do about it. Build this the way you'd want to hear it if you were the one making the call: what's the situation, what changed, what's the real question in front of us, and what's the answer. Then you'll present it to us directly.$t$::text))
FROM rounds r WHERE a.round_id = r.round_id AND r.simulation_id = sim
  AND r.round_number = 5 AND a.artifact_type = 'BOARD_MEMO';

END $$;
