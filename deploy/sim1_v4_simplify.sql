-- ============================================================================
-- Simulator 1 (Phoenix AI Judgment) — v4 "simplify" pass
--
-- Driven by student feedback that the simulation was at times hard to follow.
-- Three data changes, all IN PLACE. No artifact, decision or option row is
-- created or deleted, and no option `id` (action code) changes — so scoring,
-- the adaptive-content variants and the cautious-order conflict resolution all
-- continue to resolve exactly as before.
--
--   1. The opening CRO Note is cut from ~350 words to ~140. The stakes it used
--      to carry (bonuses, client signings, the regulatory review, the $12.9M
--      figure) move to the pre-simulation context page, where students read
--      them before any clock is running.
--
--   2. The CEO's four round-ending decisions get a short headline plus a
--      separate explanation line. They previously rendered as a single button
--      holding a 100-170 character paragraph; three of those side by side, at
--      the most consequential moment of the round, is the densest thing in the
--      simulation. Needs the matching ArtifactDetail.jsx change to show the
--      second line.
--
--   3. Six decisions in Rounds 3 and 4 are retired by setting allowed_roles to
--      an empty array. Those two rounds were the only ones with NO read-only
--      artifacts at all — every single item demanded an answer. Each retired
--      decision is the weaker half of a same-role pair on the same thread.
--
--      Retiring rather than deleting is deliberate. An empty allowed_roles
--      fails every branch of the role test in findExpiredUnansweredDecisions,
--      so no SILENCE row and no No-Response penalty is ever recorded; and it
--      falls into the READ_ONLY arm of the visibility CASE, so the artifact
--      still arrives in the Inbox and is still read, it just isn't asked for.
--      This is the same mechanism the Round-2 Leadership Alignment Meeting has
--      used in production since v2. The decision row also survives, so the
--      1,173 recorded decision_events keep their foreign keys.
--
-- Rollback for each statement is noted inline.
-- ============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Trim the opening CRO Note (R1, T+0)
--    Rollback: restore payload->>'body' from the backup taken before this ran.
-- ---------------------------------------------------------------------------
UPDATE artifacts
SET payload = jsonb_set(
      payload,
      '{body}',
      to_jsonb($body$I want to flag something small.

Phoenix Sentinel — our AI system for fraud and anti-money-laundering screening — has produced a handful of anomaly flags that don't match its own stated reasoning. No customer complaint. No financial loss. No regulatory breach. Compliance says none of it crosses our escalation threshold.

But 'AI inaccuracy' means different things to different teams here, and we've never agreed on a shared definition. Engineering calls it normal edge-case behaviour. Operations has seen similar flags resolve on their own.

No one outside the company knows. I'm not asking for a rollback — I'm asking whether it deserves your attention.

Acting now slows the rollout and invites scrutiny. Waiting risks letting a small problem grow unnoticed.

This isn't a crisis yet. It's a judgment call about a system none of us fully understands.$body$::text)
    )
WHERE artifact_id = 'a1000000-0000-4000-a001-000000001000';

-- ---------------------------------------------------------------------------
-- 2. Round-ending decisions: headline + explanation.
--    Option ids are reproduced verbatim; only the presentation changes.
--    Rollback: restore decisions.options from the backup.
-- ---------------------------------------------------------------------------

-- Round 1 — Submit Round 1 Decision
UPDATE decisions SET options = $json$[
  {"id":"OPERATIONAL_NOISE","label":"Technical monitoring matter",
   "detail":"Engineering owns it. No broader leadership framing needed."},
  {"id":"BOUNDED_UNCERTAINTY","label":"Commercial risk to the rollout",
   "detail":"Leadership owns it as a speed problem, framed around protecting the timeline."},
  {"id":"GOVERNANCE_RISK","label":"Governance matter",
   "detail":"Leadership owns it as a trust problem, framed around what happens if it's wrong later."}
]$json$::jsonb
WHERE decision_id = 'd1000000-0000-4000-a001-000000001016';

-- Round 2 — Submit Round 2 Framing
UPDATE decisions SET options = $json$[
  {"id":"CONTAINED_MATTER","label":"Contained operational matter",
   "detail":"Hold the language. Nothing has technically changed since Round 1."},
  {"id":"MONITORING_REPORTING","label":"Structured reporting, no escalation",
   "detail":"Treat this as a process gap to fix, not a risk finding."},
  {"id":"GOVERNANCE_OVERSIGHT","label":"Governance oversight, formal documentation",
   "detail":"Put it on record now, before someone outside the company does."}
]$json$::jsonb
WHERE decision_id = 'd1000000-0000-4000-a001-000000001033';

-- Round 3 — Submit Round 3 Framing
UPDATE decisions SET options = $json$[
  {"id":"MAINTAIN_MONITORING","label":"Maintain internal monitoring",
   "detail":"Two rounds of stable signal. Changing course now would be reacting to attention, not evidence."},
  {"id":"FORMALIZE_REPORTING","label":"Formalize reporting, no escalation",
   "detail":"Add rigour to the process without declaring a finding we don't have."},
  {"id":"ELEVATE_GOVERNANCE","label":"Elevate to board visibility",
   "detail":"The pattern of repeated outside questions is itself the signal, even if the anomaly hasn't changed."}
]$json$::jsonb
WHERE decision_id = 'd1000000-0000-4000-a001-000000001048';

-- Round 4 — Final Round 4 Decision
UPDATE decisions SET options = $json$[
  {"id":"PROPORTIONAL_RESPONSE","label":"Proportional response",
   "detail":"The team read weak signals correctly and didn't overreact to noise. This is good judgment under ambiguity."},
  {"id":"FRAGMENTED_ALIGNMENT","label":"Fragmented alignment",
   "detail":"Different functions read the same signals differently and never reconciled. A process lesson, not a judgment one."},
  {"id":"UNDERRECOGNIZED_EXPOSURE","label":"Under-recognized governance exposure",
   "detail":"Across four rounds there was enough signal to act sooner, and the incentive structure made sure nobody did."}
]$json$::jsonb
WHERE decision_id = 'd1000000-0000-4000-a001-000000001062';

-- ---------------------------------------------------------------------------
-- 3. Retire six duplicate decisions in Rounds 3 and 4.
--    The artifacts stay in the Inbox as read-only context.
--    Rollback: the previous allowed_roles are restored by
--      d...1038 -> ["PRODUCT"]              d...1057 -> ["HEAD_OF_ENGINEERING"]
--      d...1039 -> ["CEO"]                  d...1059 -> ["PRODUCT"]
--      d...1042 -> ["OPERATIONS"]           d...1060 -> ["CHRO"]
-- ---------------------------------------------------------------------------
UPDATE decisions SET allowed_roles = '[]'::jsonb
WHERE decision_id IN (
  'd1000000-0000-4000-a001-000000001038',  -- R3 Enterprise Client Query   (Product)
  'd1000000-0000-4000-a001-000000001039',  -- R3 Internal Audit Check-In   (CEO)
  'd1000000-0000-4000-a001-000000001042',  -- R3 Workflow Audit Outcome    (Operations)
  'd1000000-0000-4000-a001-000000001057',  -- R4 Audit Trail Confirmation  (Engineering)
  'd1000000-0000-4000-a001-000000001059',  -- R4 Renewal Outcome           (Product)
  'd1000000-0000-4000-a001-000000001060'   -- R4 Whistle Channel Check     (CHRO)
);

COMMIT;
