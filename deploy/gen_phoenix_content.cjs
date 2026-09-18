/**
 * Generates the full SQL seed for Simulation 3 — "Trust the Machine" (ANP Phoenix, new script).
 *
 * Same engine, same round/artifact skeleton as Sim 1, but the new script's content, its four
 * redefined variables, and its explicit +1/0/-1 scoring.
 *
 * VARIABLE MAPPING — the engine stores four deltas per option; the new script's four variables map
 * onto them one-for-one, and the DIRECTION of each column is preserved so nothing downstream has to
 * special-case sim3 arithmetic:
 *
 *   Stakeholder Trust        -> trust_delta      (higher = better)   same as Sim 1
 *   Governance Accountability-> risk_delta       (higher = better)   NOTE: Sim 1 used this column for
 *                                                                    "Organizational Risk" where high
 *                                                                    was BAD. Sim 3 relabels it and
 *                                                                    flips the direction, which is a
 *                                                                    display concern only (see the
 *                                                                    per-simulation label map in
 *                                                                    ArtifactReadService/ResultsDashboard).
 *   Diagnostic Rigor         -> execution_delta  (higher = better)   same shape as Sim 1
 *   Ethical Exposure         -> ethics_delta     (higher = WORSE)    same as Sim 1; script scores +1
 *                                                                    for the exposure-raising choice
 *
 * SCALE — the script scores ±1 per decision. The engine bands a 0-100 value off a 50 baseline
 * (>=67 High, >=34 Medium), so a raw ±1 would never move a team out of Medium. Each script point is
 * therefore worth SCALE engine points; with ~12-20 scored decisions per variable this puts a
 * consistently transparent team near the top of the range and a consistently evasive one near the
 * bottom, which is exactly the spread the script's bucketing section asks for.
 */
const fs = require("fs");
const path = require("path");

const SIM = "5c3d0000-0000-4000-a003-000000000003";
const SCALE = 10;

// ── helpers ──────────────────────────────────────────────────────────────────
const q = (s) => (s === null || s === undefined ? "NULL" : `'${String(s).replace(/'/g, "''")}'`);
const j = (o) => `'${JSON.stringify(o).replace(/'/g, "''")}'::jsonb`;

let artN = 0, decN = 0, optN = 0, condN = 0;
const aid = () => `a3000000-0000-4000-a003-${String(++artN).padStart(12, "0")}`;
const did = () => `d3000000-0000-4000-a003-${String(++decN).padStart(12, "0")}`;
const oid = () => `03000000-0000-4000-a003-${String(++optN).padStart(12, "0")}`;
const cid = () => `c3000000-0000-4000-a003-${String(++condN).padStart(12, "0")}`;

const sql = [];
const contentModel = []; // authored structure, exported so the Sim 1 in-place updater shares this source
const roundIds = {};
const decisionRef = {}; // name -> decision_id, for conditionals + adaptive variants

/**
 * @param scores per-option map: { ACTION: {trust, gov, rigor, exposure} } in SCRIPT points (±1/0)
 */
function artifact(round, {
  type, tab, open, expiry, roles, title, payload = {},
  decision = null, // { type: 'IMPLICIT'|'EXPLICIT'|'FINAL', roles: [...], options: [{id,label}], scores: {}, ref }
  condition = null, // { on: 'refName', actions: ['A','B'], crossRole: true|false }
}) {
  const artifactId = aid();
  const authoredOpen = open;
  open = scaleOpen(round, open);
  expiry = R[round];
  const full = { tab, title, ...payload };
  sql.push(
    `INSERT INTO artifacts (artifact_id, round_id, artifact_type, open_offset_min, expiry_offset_min, expected_action, payload, allowed_roles) VALUES (` +
      `${q(artifactId)}, ${q(roundIds[round])}, ${q(type)}, ${open}, ${expiry}, ${decision ? "true" : "false"}, ${j(full)}, ` +
      `${roles === "ALL" ? "NULL" : j(roles)});`,
  );

  contentModel.push({
    round, title, authoredOpen, payload: full, type, roles: roles === "ALL" ? "ALL" : roles,
    decision: decision
      ? {
          type: decision.type,
          isFinal: decision.type === "FINAL",
          // Positional: the Sim 1 updater matches these against the live rows by ORDER, and verifies
          // the label of each before writing, so a reordering upstream fails loudly instead of
          // silently scoring the wrong option.
          options: decision.options.map((o) => ({
            id: o.id,
            label: o.label,
            scores: (decision.scores && decision.scores[o.id]) || {},
          })),
        }
      : null,
  });

  if (decision) {
    const decisionId = did();
    if (decision.ref) decisionRef[decision.ref] = decisionId;
    const isFinal = decision.type === "FINAL";
    sql.push(
      `INSERT INTO decisions (decision_id, artifact_id, decision_type, is_final, options, allowed_roles) VALUES (` +
        `${q(decisionId)}, ${q(artifactId)}, ${q(isFinal ? "EXPLICIT" : decision.type)}, ${isFinal}, ` +
        `${j(decision.options)}, ${j(decision.roles)});`,
    );
    for (const opt of decision.options) {
      const s = (decision.scores && decision.scores[opt.id]) || {};
      const t = (s.trust || 0) * SCALE;
      const g = (s.gov || 0) * SCALE;
      const r = (s.rigor || 0) * SCALE;
      const e = (s.exposure || 0) * SCALE;
      sql.push(
        `INSERT INTO decision_options (option_id, decision_id, action, trust_delta, risk_delta, ethics_delta, execution_delta) VALUES (` +
          `${q(oid())}, ${q(decisionId)}, ${q(opt.id)}, ${t}, ${g}, ${e}, ${r});`,
      );
    }
  }

  if (condition) {
    sql.push(
      `INSERT INTO artifact_conditions (id, artifact_id, depends_on_decision_id, expected_action, cross_role, created_at) VALUES (` +
        `${q(cid())}, ${q(artifactId)}, ${q("@@" + condition.on + "@@")}, ${q(condition.actions.join(","))}, ${condition.crossRole}, now());`,
    );
  }
  return artifactId;
}

// ── simulation, roles, rounds ────────────────────────────────────────────────
sql.push(`DELETE FROM simulation_roles WHERE simulation_id = ${q(SIM)};`);
// Timing profiles. "full" is the script as written (17+16+14+13 = 60 min). "compressed" keeps the
// same content and the same ORDER of arrivals but fast-tracks their release into a 20-minute run,
// with each round and its feed phase scaled by the same ratio so the shape of a round survives.
const PROFILES = {
  full: { R: { 1: 17, 2: 16, 3: 14, 4: 13 }, FEED: { 1: 8, 2: 8, 3: 7, 4: 6 } },
  // 6+5+5+4 = 20 minutes. Each round keeps proportionally more of its length as feed than the full
  // version does, because at this scale the feed is what needs the granularity: with only two or
  // three distinct minutes to land on, one extra feed minute is the difference between artifacts
  // arriving in two clumps and arriving in a recognisable sequence. Deliberation is deliberately
  // short here — this profile is for a fast run-through, not a discussion session.
  compressed: { R: { 1: 6, 2: 5, 3: 5, 4: 4 }, FEED: { 1: 4, 2: 3, 3: 3, 4: 2 } },
};
const PROFILE = PROFILES[process.env.PROFILE || "full"];
if (!PROFILE) { console.error("unknown PROFILE"); process.exit(1); }
const FEED_FULL = { 1: 8, 2: 8, 3: 7, 4: 6 };  // authored feed length, the basis for rescaling
const DURATIONS = PROFILE.R;

sql.push(
  `INSERT INTO simulations (simulation_id, name, description, total_rounds, duration_minutes) VALUES (` +
    `${q(SIM)}, ${q("Trust the Machine")}, ` +
    `${q("ANP Phoenix — a leadership judgment simulation in the AI era. When can you trust what your AI just told you?")}, 4, ${Object.values(PROFILE.R).reduce((a,b)=>a+b,0)}) ` +
    `ON CONFLICT (simulation_id) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, ` +
    `total_rounds = EXCLUDED.total_rounds, duration_minutes = EXCLUDED.duration_minutes;`,
);

const ROLES = [
  ["CEO", "CEO", 1, true],
  ["CFO", "CFO", 2, false],
  ["HEAD_OF_ENGINEERING", "Head of Engineering", 3, false],
  ["PRODUCT", "Head of Product", 4, false],
  ["OPERATIONS", "Head of Operations", 5, false],
  ["CHRO", "CHRO", 6, false],
];
for (const [code, name, ord, lead] of ROLES) {
  sql.push(
    `INSERT INTO simulation_roles (simulation_id, role_code, display_name, ordinal, is_lead) VALUES (` +
      `${q(SIM)}, ${q(code)}, ${q(name)}, ${ord}, ${lead});`,
  );
}


for (const n of [1, 2, 3, 4]) {
  roundIds[n] = `43000000-0000-4000-a003-00000000000${n}`;
  sql.push(
    `INSERT INTO rounds (round_id, simulation_id, round_number, duration_minutes) VALUES (` +
      `${q(roundIds[n])}, ${q(SIM)}, ${n}, ${DURATIONS[n]});`,
  );
}

const R = PROFILE.R;         // round length
const DELIB = PROFILE.FEED;  // deliberation starts = end of the feed phase

/**
 * Rescales an authored open-offset into the active profile. Feed-phase artifacts are mapped
 * proportionally onto the compressed feed window, so their ORDER and relative spacing survive even
 * though several can land on the same minute once the window is only two or three minutes wide.
 * Anything authored at or after the feed boundary (the round-ending prompts) pins to the new
 * deliberation start instead, so the CEO never loses the window to submit.
 */
function scaleOpen(round, open) {
  if (PROFILE === PROFILES.full) return open;
  if (open >= FEED_FULL[round]) return DELIB[round];
  return Math.min(DELIB[round] - 1, Math.round((open * DELIB[round]) / FEED_FULL[round]));
}

// ════════════════════════════════════════════════════════════════════════════
// ROUND 1 — Weak Signal, Strong Incentives
// ════════════════════════════════════════════════════════════════════════════
artifact(1, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 0, expiry: R[1], roles: "ALL", title: "CRO Note",
  payload: {
    from: "Chief Risk Officer", from_email: "cro@anpphoenix.com", to: "Senior Leadership Team",
    classification: "Company Sensitive",
    body:
      "I want to flag something small. Phoenix Sentinel — our AI system that screens transactions for fraud and money laundering, and drafts client reports — has produced a handful of anomaly flags that don't fully match its own stated reasoning. It hasn't caused a customer complaint, a financial loss, or a regulatory breach. Compliance says none of this crosses our internal escalation threshold.\n\n" +
      "But 'AI inaccuracy' means different things to different teams here, and we've never agreed on a shared definition. Engineering thinks this is normal edge-case behavior. Operations has seen similar flags before and they resolved on their own.\n\n" +
      "No one outside the company knows about this. I'm not asking for a rollback — I'm asking whether it deserves your attention.\n\n" +
      "Some context that makes this harder than it sounds: your bonuses are tied to how fast Sentinel rolls out. Two large clients are about to sign, citing Sentinel by name. A regulatory review of our AI governance is six weeks out. For scale — one industry estimate puts the average cost of poor AI data and model quality at $12.9 million a year for a large company, and a recent CEO survey found most CEOs worry about the quality of the data behind their own decisions.\n\n" +
      "Acting now slows Sentinel down and invites scrutiny of the whole program. Waiting risks letting a small problem inside a live AI system grow unnoticed. Legal's view: escalating now, without a clearer trigger, creates a paper trail we can't undo.\n\n" +
      "This isn't a crisis yet. It's a judgment call about a system none of us fully understands, made by people who've already told the market we trust it.",
    pressure_cues: "Quarter close in 4 weeks. Senior leadership aligned around the growth story. \"Safe, fast AI\" reputation at stake.",
  },
});

artifact(1, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 1, expiry: R[1], roles: ["CFO"], title: "Finance Memo",
  payload: {
    from: "FP&A", from_email: "fpa@anpphoenix.com",
    body:
      "Pausing Sentinel-linked client onboarding for even a week pushes real revenue out of this quarter. Last time we missed guidance by 1%, the stock dropped 6–8% in days. Separately — Sentinel's actual running cost has grown past what we budgeted, even as the underlying AI models themselves have gotten cheaper. We haven't explained that gap to the Board yet.",
    inner_voice: "My bonus is tied to how fast Sentinel rolls out, not how accurate it is.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CFO"], ref: "r1_finance_memo",
    options: [
      { id: "DO_NOTHING", label: "Do nothing" },
      { id: "FORWARD_TO_CEO", label: "Forward to CEO" },
      { id: "FLAG_CONCERN", label: "Add comment flagging concern" },
    ],
    scores: { DO_NOTHING: { gov: -1 }, FORWARD_TO_CEO: { gov: 0 }, FLAG_CONCERN: { gov: 1 } },
  },
});

artifact(1, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 1, expiry: R[1], roles: ["PRODUCT"], title: "Sentinel Adoption Snapshot",
  payload: {
    from: "Growth Analytics", from_email: "growth-analytics@anpphoenix.com",
    body: "Sentinel-enabled client onboarding is running 22% faster this quarter. Two enterprise prospects want to reference these numbers publicly.",
    inner_voice: "My whole pitch to the Board next month leans on this number holding up.",
  },
  decision: {
    type: "IMPLICIT", roles: ["PRODUCT"],
    options: [
      { id: "APPROVE_EXTERNAL", label: "Approve for external reference" },
      { id: "HOLD_INTERNAL", label: "Hold for internal use only" },
      { id: "ASK_ENGINEERING", label: "Ask Engineering to confirm the number first" },
    ],
    scores: {
      APPROVE_EXTERNAL: { trust: -1, rigor: -1 },
      HOLD_INTERNAL: { trust: 0, rigor: 0 },
      ASK_ENGINEERING: { trust: 1, rigor: 1 },
    },
  },
});

artifact(1, {
  type: "DIAGNOSTIC_NOTE", tab: "inbox", open: 2, expiry: R[1], roles: ["CEO"], title: "Finance Clarification",
  payload: {
    from: "Sentinel Model Monitoring", from_email: "sentinel-monitoring@anpphoenix.com", conditional: true,
    body: "Early logging shows Sentinel's anomalies cluster in one narrow type of transaction, where its explanation doesn't quite match what it actually flagged. Nothing points to a bigger, systemic problem yet — but a deeper look could turn one up. Logging in more detail will slow the system down slightly and make the issue more visible internally.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CEO"],
    options: [
      { id: "PROCEED_DIAGNOSTICS", label: "Proceed with extended diagnostics" },
      { id: "PAUSE_DIAGNOSTICS", label: "Pause diagnostics pending leadership guidance" },
    ],
    scores: { PROCEED_DIAGNOSTICS: { rigor: 1 }, PAUSE_DIAGNOSTICS: { rigor: -1 } },
  },
  condition: { on: "r1_finance_memo", actions: ["FORWARD_TO_CEO", "FLAG_CONCERN"], crossRole: true },
});

artifact(1, {
  type: "PEOPLE_SIGNAL", tab: "inbox", open: 2, expiry: R[1], roles: ["CHRO"], title: "Culture Pulse — Early Read",
  payload: {
    from: "People Analytics", from_email: "people-analytics@anpphoenix.com",
    body: "Early read: engineering and ops teams say they feel 'rushed but not unsafe' about Sentinel's pace. Small sample — read with caution.",
    inner_voice: "That phrase looks fine on paper. It's exactly the kind of phrase that ages badly.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CHRO"],
    options: [
      { id: "NOTE_AND_MOVE_ON", label: "Note and move on" },
      { id: "FULLER_PULSE", label: "Ask for a fuller pulse next cycle" },
      { id: "FLAG_PHRASING", label: "Flag the phrasing to leadership now" },
    ],
    scores: {
      NOTE_AND_MOVE_ON: { trust: -1, gov: -1 },
      FULLER_PULSE: { trust: 0, gov: 0 },
      FLAG_PHRASING: { trust: 1, gov: 1 },
    },
  },
});

artifact(1, {
  type: "EXCERPT", tab: "excerpts", open: 2, expiry: R[1], roles: ["HEAD_OF_ENGINEERING"], title: "#sentinel-model-integrity",
  payload: {
    channel: "#sentinel-model-integrity",
    messages: [
      { from: "eng-1", text: "Sentinel's confidence scores don't match its own explanations. It's small. Hard to explain cleanly." },
      { from: "eng-2", text: "If we actually dig into why, we might not like the answer." },
    ],
    inner_voice: "I don't have a fix yet. Digging deeper might mean admitting we shipped Sentinel too fast — but if I raise it without proof, I'll get called an alarmist.",
  },
  decision: {
    type: "EXPLICIT", roles: ["HEAD_OF_ENGINEERING"], ref: "r1_slack_eng",
    options: [
      { id: "TAG_KNOWN_ISSUE", label: "Tag as \"known issue (monitor)\"" },
      { id: "LEAVE_UNTAGGED", label: "Leave untagged" },
      { id: "FLAG_INVESTIGATION", label: "Flag for deeper model investigation" },
    ],
    scores: { TAG_KNOWN_ISSUE: { rigor: 0 }, LEAVE_UNTAGGED: { rigor: -1 }, FLAG_INVESTIGATION: { rigor: 1 } },
  },
});

artifact(1, {
  type: "MESSAGE_TEXT", tab: "inbox", open: 3, expiry: R[1], roles: ["CEO"], title: "Board Message",
  payload: {
    from: "Office of the Board Chair", from_email: "board-chair@anpphoenix.com",
    body: "The AI governance review is procedural. Let's not complicate things unnecessarily.",
    inner_voice: "My credibility with this Board on anything AI-related is still new. Two years ago, a smaller AI issue got escalated early — the stock dipped and nothing came of it.",
  },
  decision: {
    type: "EXPLICIT", roles: ["CEO"],
    options: [
      { id: "REASSURE", label: "Reassure" },
      { id: "FLAG_UNCERTAINTY", label: "Flag uncertainty" },
      { id: "NO_RESPONSE_OPT", label: "Do not respond" },
    ],
    scores: {
      REASSURE: { trust: -1, gov: -1 },
      FLAG_UNCERTAINTY: { trust: 1, gov: 1 },
      NO_RESPONSE_OPT: { trust: 0, gov: 0 },
    },
  },
});

artifact(1, {
  type: "DIAGNOSTIC_NOTE", tab: "inbox", open: 3, expiry: R[1], roles: ["HEAD_OF_ENGINEERING"], title: "Diagnostic Summary",
  payload: {
    from: "Sentinel Model Monitoring (automated)", from_email: "sentinel-monitoring@anpphoenix.com", conditional: true,
    body: "Early logging shows Sentinel's anomalies cluster in one narrow type of transaction, where its explanation doesn't quite match what it actually flagged. Nothing points to a systemic problem yet — but a deeper look could turn one up. More detailed logging will slow the system slightly and make the issue more visible internally.",
  },
  decision: {
    type: "EXPLICIT", roles: ["HEAD_OF_ENGINEERING"], ref: "r1_diagnostics",
    options: [
      { id: "PROCEED_DIAGNOSTICS", label: "Proceed with extended diagnostics" },
      { id: "PAUSE_DIAGNOSTICS", label: "Pause diagnostics pending leadership guidance" },
    ],
    scores: { PROCEED_DIAGNOSTICS: { rigor: 1 }, PAUSE_DIAGNOSTICS: { rigor: -1 } },
  },
  condition: { on: "r1_slack_eng", actions: ["FLAG_INVESTIGATION"], crossRole: false },
});

artifact(1, {
  type: "OPS_DASHBOARD", tab: "excerpts", open: 3, expiry: R[1], roles: ["OPERATIONS"], title: "Sentinel Operations Dashboard — Live",
  payload: {
    dashboard: [
      { metric: "Uptime", value: "99.6%", status: "green" },
      { metric: "Manual override queue", value: "340 cases, up from a 210 weekly average", status: "amber" },
      { metric: "Client-facing incidents", value: "0 logged", status: "green" },
    ],
    body: "The override queue has climbed for three straight weeks; nobody has looked into why yet.",
    inner_voice: "Pausing Sentinel-dependent work mid-rollout has caused bigger problems before than the ones we paused for.",
  },
  decision: {
    type: "IMPLICIT", roles: ["OPERATIONS"],
    options: [
      { id: "FLAG_INVESTIGATION", label: "Flag for deeper investigation" },
      { id: "RAISE_TO_CEO", label: "Raise concern to CEO" },
      { id: "CONTINUE_SILENTLY", label: "Continue workaround silently" },
    ],
    scores: {
      FLAG_INVESTIGATION: { rigor: 1 },
      RAISE_TO_CEO: { gov: 1 },
      CONTINUE_SILENTLY: { exposure: 1 },
    },
  },
});

artifact(1, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 4, expiry: R[1], roles: ["CFO"], title: "Analyst Coverage Note",
  payload: {
    from: "Investor Relations", from_email: "ir@anpphoenix.com",
    body: "A sell-side analyst's unpublished draft frames our AI story as 'ahead of peers on speed, unclear on safety.' They may ask about it on the earnings call.",
    inner_voice: "The \"ahead on speed\" half is the version I'd like everyone to remember.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CFO"],
    options: [
      { id: "PREPARE_RESPONSE", label: "Prepare a response now" },
      { id: "WAIT_AND_SEE", label: "Wait and see if it's published" },
      { id: "LOOP_IN_PRODUCT", label: "Loop in Product before responding" },
    ],
    scores: { PREPARE_RESPONSE: { trust: 0 }, WAIT_AND_SEE: { trust: -1 }, LOOP_IN_PRODUCT: { trust: 1 } },
  },
});

artifact(1, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 4, expiry: R[1], roles: ["PRODUCT"], title: "Client Reference Call Prep",
  payload: {
    from: "Enterprise Sales", from_email: "enterprise-sales@anpphoenix.com",
    body: "A prospective client wants a reference call this week and will ask directly how Sentinel's fraud alerts are checked before going live.",
    inner_voice: "I don't actually know the honest answer to that question right now.",
  },
  decision: {
    type: "IMPLICIT", roles: ["PRODUCT"],
    options: [
      { id: "CONFIDENT_ANSWER", label: "Prepare a confident standard answer" },
      { id: "LOOP_IN_ENGINEERING", label: "Loop in Engineering before the call" },
      { id: "PUSH_CALL_BACK", label: "Push the call back a week" },
    ],
    scores: {
      CONFIDENT_ANSWER: { trust: -1, rigor: -1 },
      LOOP_IN_ENGINEERING: { trust: 1, rigor: 1 },
      PUSH_CALL_BACK: { trust: 0, rigor: 0 },
    },
  },
});

artifact(1, {
  type: "PEOPLE_SIGNAL", tab: "excerpts", open: 5, expiry: R[1], roles: ["CHRO"], title: "Pulse Survey + Exit Interview",
  payload: {
    from: "People Analytics", from_email: "people-analytics@anpphoenix.com",
    pulse: "Pulse feedback: managers aren't sure whether raising concerns about Sentinel is something leadership actually wants to hear, or whether it reads as 'not being AI-ready.'",
    exit_note: "Exit interview, senior engineer, three months ago: \"We learned quickly what not to say about the model.\"",
    inner_voice: "No one has used the formal whistleblower channel.",
  },
  decision: {
    type: "EXPLICIT", roles: ["CHRO"],
    options: [
      { id: "ENCOURAGE_ESCALATION", label: "Issue guidance encouraging escalation" },
      { id: "DEFER_GUIDANCE", label: "Defer guidance" },
      { id: "REINFORCE_DELIVERY", label: "Reinforce delivery focus" },
    ],
    scores: {
      ENCOURAGE_ESCALATION: { trust: 1, exposure: -1 },
      DEFER_GUIDANCE: { trust: 0, exposure: 0 },
      REINFORCE_DELIVERY: { trust: -1, exposure: 1 },
    },
  },
});

artifact(1, {
  type: "MEETING_INVITE", tab: "meetings", open: 6, expiry: R[1], roles: ["CEO"], title: "Calendar Conflict",
  payload: {
    meeting_a: "Sentinel anomaly review",
    meeting_b: "Enterprise client call — Sentinel go-live",
    body: "Two meetings overlap.",
  },
  decision: {
    type: "EXPLICIT", roles: ["CEO"],
    options: [
      { id: "ATTEND_ANOMALY_REVIEW", label: "Attend anomaly review" },
      { id: "ATTEND_CLIENT_CALL", label: "Attend client call" },
    ],
    scores: { ATTEND_ANOMALY_REVIEW: { gov: 1, rigor: 1 }, ATTEND_CLIENT_CALL: { gov: -1, rigor: -1 } },
  },
});

artifact(1, {
  type: "TAGGING_CHECK", tab: "inbox", open: 6, expiry: R[1], roles: ["HEAD_OF_ENGINEERING", "OPERATIONS"], title: "Internal Tagging",
  payload: {
    from: "AI Risk Register (automated)", from_email: "ai-risk-register@anpphoenix.com",
    body: "Classify Sentinel's anomaly status for the AI risk register.",
  },
  decision: {
    type: "EXPLICIT", roles: ["HEAD_OF_ENGINEERING", "OPERATIONS"], ref: "r1_tagging",
    options: [
      { id: "OPERATIONAL_NOISE", label: "Operational noise" },
      { id: "UNDER_OBSERVATION", label: "Under observation" },
      { id: "REQUIRES_REVIEW", label: "Requires review" },
    ],
    scores: { OPERATIONAL_NOISE: { rigor: -1 }, UNDER_OBSERVATION: { rigor: 0 }, REQUIRES_REVIEW: { rigor: 1 } },
  },
});

artifact(1, {
  type: "INVESTOR_DRAFT", tab: "inbox", open: 7, expiry: R[1], roles: ["CFO", "PRODUCT"], title: "Investor Draft",
  payload: {
    from: "Investor Relations", from_email: "ir@anpphoenix.com",
    body: "\"Our GenAI capabilities, anchored by Phoenix Sentinel, are accurate across every setting we've deployed in and represent a safe bet for the enterprise.\"",
    inner_voice_cfo: "Our biggest competitor is announcing a \"trust-first AI\" campaign next quarter.",
    inner_voice_product: "Sentinel is the proof point investors want for our AI story.",
  },
  decision: {
    type: "EXPLICIT", roles: ["CFO", "PRODUCT"], ref: "r1_investor_draft",
    options: [
      { id: "APPROVE", label: "Approve" },
      { id: "SOFT_EDIT", label: "Soft-edit" },
      { id: "REMOVE", label: "Remove" },
    ],
    scores: {
      APPROVE: { trust: -1, exposure: 1 },
      SOFT_EDIT: { trust: 0, exposure: 0 },
      REMOVE: { trust: 1, exposure: -1 },
    },
  },
});

artifact(1, {
  type: "SCREEN_FLASH", tab: "inbox", open: DELIB[1], expiry: R[1], roles: "ALL", title: "All-Clear Signal",
  payload: { body: "No external escalation has occurred. All quiet — for now.", display_style: "flash" },
});

artifact(1, {
  type: "SCREEN_FLASH", tab: "decisions", open: DELIB[1], expiry: R[1], roles: ["CEO"], title: "Submit Round 1 Decision",
  payload: {
    is_final_round_decision: true,
    body: "Based on what you know now, how should this be framed internally, for now?",
  },
  decision: {
    type: "FINAL", roles: ["CEO"], ref: "r1_final",
    options: [
      { id: "TECHNICAL_MONITORING", label: "This is a technical monitoring matter — Engineering owns it, no broader leadership framing needed." },
      { id: "COMMERCIAL_RISK", label: "This is a commercial risk to the rollout — leadership owns it as a speed problem, framed around protecting the timeline." },
      { id: "GOVERNANCE_MATTER", label: "This is a governance matter — leadership owns it as a trust problem, framed around what happens if it's wrong later." },
    ],
    scores: {}, // unscored by design (script 1.8 / 2.5)
  },
});

// ════════════════════════════════════════════════════════════════════════════
// ROUND 2 — When Ambiguity Becomes Discussable
// ════════════════════════════════════════════════════════════════════════════
artifact(2, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 0, expiry: R[2], roles: "ALL", title: "Internal Recap Memo",
  payload: {
    from: "Strategy Office", from_email: "strategy@anpphoenix.com",
    body: "As discussed, this stays with Engineering as a monitoring matter. No broader escalation at this stage.",
    variant_on: { field: "body", cross_role: true, decision_id: "@@r1_final@@" },
    variants: {
      TECHNICAL_MONITORING: "As discussed, this stays with Engineering as a monitoring matter. No broader escalation at this stage.",
      COMMERCIAL_RISK: "As discussed, we're protecting the rollout. Diagnostics continue on a faster timeline to keep the program on track.",
      GOVERNANCE_MATTER: "As discussed, Sentinel's anomalies now carry formal governance visibility. Documentation and logging are underway.",
    },
  },
});

artifact(2, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 1, expiry: R[2], roles: "ALL", title: "Responsible AI Governance Note",
  payload: {
    from: "Strategy & Risk Office", from_email: "strategy-risk@anpphoenix.com",
    body:
      "ANP Phoenix commits to deploying AI safely, transparently, and fairly. This rests on four commitments, aligned with practices such as NIST's AI Risk Management Framework:\n\n" +
      "Fair and human-centered — understand who's affected and reduce unfair bias.\n" +
      "Trusted and transparent — say where AI is used and check its outputs.\n" +
      "Safe and secure — watch for safety problems and protect data from misuse.\n" +
      "Accountable and well-governed — keep clear documentation and ownership for every model we run.",
  },
});

artifact(2, {
  type: "EXCERPT", tab: "excerpts", open: 1, expiry: R[2], roles: ["OPERATIONS"], title: "Override Queue Update",
  payload: {
    from: "Ops Control Room", from_email: "ops-control@anpphoenix.com",
    body: "Override queue is still climbing — 340 to 410 in two days. No incident yet, but the trend line is the real story now, not the raw number.",
  },
  decision: {
    type: "IMPLICIT", roles: ["OPERATIONS"],
    options: [
      { id: "ESCALATE_TREND", label: "Escalate the trend now" },
      { id: "KEEP_MONITORING", label: "Keep monitoring at current cadence" },
      { id: "REDUCE_REVIEW", label: "Reduce manual review to clear the backlog faster" },
    ],
    scores: { ESCALATE_TREND: { gov: 1 }, KEEP_MONITORING: { gov: 0 }, REDUCE_REVIEW: { gov: -1 } },
  },
});

artifact(2, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 2, expiry: R[2], roles: ["PRODUCT"], title: "Adoption Metrics Check-In",
  payload: {
    from: "Growth Analytics", from_email: "growth-analytics@anpphoenix.com",
    body: "Sentinel adoption among enterprise clients ticked up again this week. Nobody outside this room is asking about the anomaly.",
  },
  decision: {
    type: "IMPLICIT", roles: ["PRODUCT"],
    options: [
      { id: "KEEP_PUSHING", label: "Keep pushing the adoption number externally" },
      { id: "QUIETLY_PAUSE", label: "Quietly pause external references to Sentinel's accuracy" },
      { id: "ASK_ENGINEERING", label: "Ask Engineering for a status check first" },
    ],
    scores: { KEEP_PUSHING: { trust: -1 }, QUIETLY_PAUSE: { trust: 0 }, ASK_ENGINEERING: { trust: 1 } },
  },
});

artifact(2, {
  type: "PEOPLE_SIGNAL", tab: "inbox", open: 2, expiry: R[2], roles: ["CHRO"], title: "Manager Temperature Check",
  payload: {
    from: "People Analytics", from_email: "people-analytics@anpphoenix.com",
    body: "A few team leads have asked, informally, whether it's 'safe' to keep raising questions about Sentinel in front of leadership.",
    inner_voice: "Asking that question at all is itself the answer.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CHRO"],
    options: [
      { id: "RESPOND_ENCOURAGE", label: "Respond directly and encourage them" },
      { id: "WAIT_FOR_PATTERN", label: "Note it and wait for a clearer pattern" },
      { id: "REDIRECT_MANAGER", label: "Redirect them to their manager" },
    ],
    scores: { RESPOND_ENCOURAGE: { trust: 1 }, WAIT_FOR_PATTERN: { trust: 0 }, REDIRECT_MANAGER: { trust: -1 } },
  },
});

artifact(2, {
  type: "EXCERPT", tab: "excerpts", open: 2, expiry: R[2], roles: "ALL", title: "#ai-program",
  payload: {
    channel: "#ai-program",
    messages: [
      { from: "member-1", text: "Are we still treating Sentinel's behavior as contained?" },
      { from: "member-2", text: "Depends what you mean by contained." },
      { from: "member-3", text: "I thought this was 'monitor only.'" },
      { from: "member-4", text: "Monitoring isn't the same as ignoring." },
    ],
    inner_voice: "People are starting to define \"contained\" differently, and nobody's said so out loud.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CEO", "CFO", "CHRO", "HEAD_OF_ENGINEERING", "OPERATIONS", "PRODUCT"],
    options: [
      { id: "ENGAGE_THREAD", label: "Engage in thread" },
      { id: "OBSERVE_SILENTLY", label: "Observe silently" },
      { id: "REDIRECT_OFFLINE", label: "Redirect offline" },
    ],
    scores: { ENGAGE_THREAD: { gov: 1 }, OBSERVE_SILENTLY: { gov: 0 }, REDIRECT_OFFLINE: { gov: -1 } },
  },
});

artifact(2, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 3, expiry: R[2], roles: ["CEO"], title: "Regulator Scheduling Note",
  payload: {
    from: "Regulatory Affairs", from_email: "regulatory@anpphoenix.com",
    body: "Ahead of the scheduled review, we're compiling documentation of our internal AI escalation process and model governance. Please confirm whether any recent classification changes should be included.",
  },
  decision: {
    type: "EXPLICIT", roles: ["CEO"],
    options: [
      { id: "INCLUDE_ANOMALY", label: "Include anomaly in documentation summary" },
      { id: "EXCLUDE_NON_MATERIAL", label: "Exclude as non-material" },
      { id: "DEFER_DOCUMENTATION", label: "Defer documentation decision" },
    ],
    scores: {
      INCLUDE_ANOMALY: { gov: 1, exposure: -1 },
      EXCLUDE_NON_MATERIAL: { gov: -1, exposure: 1 },
      DEFER_DOCUMENTATION: { gov: 0, exposure: 0 },
    },
  },
});

artifact(2, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 3, expiry: R[2], roles: ["CFO"], title: "Cost Variance Follow-Up",
  payload: {
    from: "FP&A", from_email: "fpa@anpphoenix.com",
    body: "Sentinel's infrastructure spend came in over forecast again this week. Nobody has asked why yet.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CFO"],
    options: [
      { id: "RAISE_AT_SYNC", label: "Raise it at the next leadership sync" },
      { id: "ABSORB_QUIETLY", label: "Absorb it quietly this quarter" },
      { id: "ASK_ENGINEERING", label: "Ask Engineering to explain the variance first" },
    ],
    scores: { RAISE_AT_SYNC: { gov: 1 }, ABSORB_QUIETLY: { gov: -1 }, ASK_ENGINEERING: { gov: 0 } },
  },
});

artifact(2, {
  type: "EXCERPT", tab: "excerpts", open: 3, expiry: R[2], roles: ["HEAD_OF_ENGINEERING"], title: "Model Monitoring Digest",
  payload: {
    from: "Sentinel Model Monitoring (automated)", from_email: "sentinel-monitoring@anpphoenix.com",
    body: "Weekly digest: anomaly rate unchanged from last week. Confidence-explanation mismatch rate unchanged. No new pattern detected.",
  },
  decision: {
    type: "IMPLICIT", roles: ["HEAD_OF_ENGINEERING"],
    options: [
      { id: "FILE_ROUTINE", label: "File as routine" },
      { id: "CROSS_CHECK", label: "Cross-check manually before filing" },
      { id: "REQUEST_AUDIT", label: "Request an out-of-cycle model audit" },
    ],
    scores: { FILE_ROUTINE: { rigor: 0 }, CROSS_CHECK: { rigor: 1 }, REQUEST_AUDIT: { rigor: 1 } },
  },
});

artifact(2, {
  type: "EXCERPT", tab: "excerpts", open: 4, expiry: R[2], roles: ["OPERATIONS"], title: "Override Escalation Decision",
  payload: {
    from: "Ops Control Room", from_email: "ops-control@anpphoenix.com",
    body: "The queue is now big enough to need a call: keep full manual review, or thin it to keep pace with volume.",
  },
  decision: {
    type: "IMPLICIT", roles: ["OPERATIONS"],
    options: [
      { id: "KEEP_FULL_REVIEW", label: "Keep full manual review" },
      { id: "THIN_REVIEW", label: "Thin review to clear backlog" },
      { id: "ESCALATE_HEADCOUNT", label: "Escalate for more headcount instead of a shortcut" },
    ],
    scores: {
      KEEP_FULL_REVIEW: { rigor: 1, exposure: -1 },
      THIN_REVIEW: { rigor: -1, exposure: 1 },
      ESCALATE_HEADCOUNT: { rigor: 1, exposure: -1 },
    },
  },
});

artifact(2, {
  type: "MEETING_INVITE", tab: "meetings", open: 5, expiry: R[2], roles: "ALL", title: "Leadership Alignment Meeting",
  payload: {
    body: "Topic: Alignment on Sentinel Monitoring Narrative. Standalone checkpoint — discussed as a group, submitted by the CEO.",
  },
  decision: {
    type: "EXPLICIT", roles: ["CEO"],
    options: [
      { id: "MAINTAIN_FRAMING", label: "Maintain prior framing" },
      { id: "RECALIBRATE_LANGUAGE", label: "Recalibrate language without escalation" },
      { id: "ELEVATE_CLASSIFICATION", label: "Formally elevate classification" },
    ],
    scores: { MAINTAIN_FRAMING: { gov: 0 }, RECALIBRATE_LANGUAGE: { gov: 0 }, ELEVATE_CLASSIFICATION: { gov: 1 } },
  },
});

artifact(2, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 5, expiry: R[2], roles: ["PRODUCT"], title: "Client Renewal Signal",
  payload: {
    from: "Enterprise Sales", from_email: "enterprise-sales@anpphoenix.com",
    body: "The client from your Round 1 reference call is now asking, directly, whether the anomaly Engineering mentioned affects their renewal.",
  },
  decision: {
    type: "EXPLICIT", roles: ["PRODUCT"],
    options: [
      { id: "REASSURE_DIRECTLY", label: "Reassure directly" },
      { id: "LOOP_IN_COMPLIANCE", label: "Loop in Compliance before responding" },
      { id: "DEFER_TO_CFO", label: "Defer to CFO's investor-facing language" },
    ],
    scores: {
      REASSURE_DIRECTLY: { trust: -1, exposure: 1 },
      LOOP_IN_COMPLIANCE: { trust: 1, exposure: -1 },
      DEFER_TO_CFO: { trust: 0, exposure: 0 },
    },
  },
});

artifact(2, {
  type: "EXCERPT", tab: "excerpts", open: 5, expiry: R[2], roles: ["CHRO"], title: "Informal Escalation Inquiry",
  payload: {
    from: "People Team", from_email: "people-team@anpphoenix.com",
    body: "\"Just checking — is it okay to raise questions about Sentinel's behavior in cross-team meetings, or should that stay inside engineering?\"",
    inner_voice: "No formal complaint. Tone is cautious.",
  },
  decision: {
    type: "EXPLICIT", roles: ["CHRO"],
    options: [
      { id: "ENCOURAGE_DISCUSSION", label: "Encourage open discussion" },
      { id: "CHANNEL_DISCIPLINE", label: "Suggest channel discipline" },
      { id: "DEFER_RESPONSE", label: "Defer response" },
    ],
    scores: { ENCOURAGE_DISCUSSION: { trust: 1 }, CHANNEL_DISCIPLINE: { trust: -1 }, DEFER_RESPONSE: { trust: 0 } },
  },
});

artifact(2, {
  type: "MESSAGE_TEXT", tab: "inbox", open: 6, expiry: R[2], roles: ["CFO"], title: "Investor Follow-Up Question",
  payload: {
    from: "Institutional Investor Relations", from_email: "ir-external@institutional.com",
    body: "Following up on your prior statement about Sentinel's robustness — can you clarify how internal monitoring works, and whether this is still a safe bet for the enterprise?",
    variant_on: {
      field: "body", cross_role: false, decision_id: "@@r1_investor_draft@@",
      cautious_order: ["REMOVE", "SOFT_EDIT", "APPROVE"],
    },
    variants: {
      APPROVE: "You told us Sentinel is accurate across every setting you've deployed in. We're following up: can you confirm that statement still holds, and explain how internal monitoring supports it?",
      SOFT_EDIT: "We noticed the language about Sentinel shifted from your earlier statement. Can you clarify what changed, how internal monitoring works, and whether this is still a safe bet for the enterprise?",
      REMOVE: "We noticed no Sentinel statement was issued this cycle, unlike previous quarters. Can you clarify why, how internal monitoring works, and whether this is still a safe bet for the enterprise?",
    },
  },
  decision: {
    type: "EXPLICIT", roles: ["CFO"],
    options: [
      { id: "HIGH_LEVEL_REASSURANCE", label: "Provide high-level reassurance" },
      { id: "STRUCTURED_DETAIL", label: "Offer structured technical detail" },
      { id: "DELAY_RESPONSE", label: "Delay response pending leadership alignment" },
    ],
    scores: {
      HIGH_LEVEL_REASSURANCE: { trust: 0, exposure: 0 },
      STRUCTURED_DETAIL: { trust: 1, exposure: -1 },
      DELAY_RESPONSE: { trust: -1, exposure: 1 },
    },
  },
});

artifact(2, {
  type: "EXCERPT", tab: "excerpts", open: 6, expiry: R[2], roles: ["HEAD_OF_ENGINEERING"], title: "#sentinel-model-integrity",
  payload: {
    channel: "#sentinel-model-integrity",
    messages: [
      { from: "eng-1", text: "We're logging more. Still no systemic failure." },
      { from: "eng-2", text: "Noise floor hasn't changed." },
    ],
    variant_on: {
      field: "messages", cross_role: false, decision_id: "@@r1_tagging@@",
      cautious_order: ["REQUIRES_REVIEW", "UNDER_OBSERVATION", "OPERATIONAL_NOISE"],
    },
    variants: {
      OPERATIONAL_NOISE: [
        { from: "eng-1", text: "Feels like we moved on quickly." },
        { from: "eng-2", text: "Or we decided not to look." },
      ],
      UNDER_OBSERVATION: [
        { from: "eng-1", text: "We're logging more. Still no systemic failure." },
        { from: "eng-2", text: "Noise floor hasn't changed." },
      ],
      REQUIRES_REVIEW: [
        { from: "eng-1", text: "We're logging more. Still no systemic failure." },
        { from: "eng-2", text: "Noise floor hasn't changed." },
      ],
    },
  },
  decision: {
    type: "IMPLICIT", roles: ["HEAD_OF_ENGINEERING"],
    options: [
      { id: "CONTINUE_STANCE", label: "Continue current stance" },
      { id: "REOPEN_REVIEW", label: "Re-open internal review" },
      { id: "MAINTAIN_SILENCE", label: "Maintain silence" },
    ],
    scores: { CONTINUE_STANCE: { rigor: 0 }, REOPEN_REVIEW: { rigor: 1 }, MAINTAIN_SILENCE: { rigor: -1 } },
  },
});

artifact(2, {
  type: "SCREEN_FLASH", tab: "inbox", open: DELIB[2], expiry: R[2], roles: "ALL", title: "Narrative Drift Check",
  payload: { body: "Internal interpretations are no longer uniform.", display_style: "flash" },
});

artifact(2, {
  type: "SCREEN_FLASH", tab: "decisions", open: DELIB[2], expiry: R[2], roles: ["CEO"], title: "Submit Round 2 Framing",
  payload: { is_final_round_decision: true, body: "Given what's been discussed, how should this now be positioned?" },
  decision: {
    type: "FINAL", roles: ["CEO"], ref: "r2_final",
    options: [
      { id: "CONTAINED_OPERATIONAL", label: "Contained operational matter — hold the language. Nothing has technically changed since Round 1." },
      { id: "STRUCTURED_REPORTING", label: "Structured reporting, no escalation — treat this as a process gap to fix, not a risk finding." },
      { id: "GOVERNANCE_OVERSIGHT", label: "Governance oversight, formal documentation — put it on record now, before someone outside the company does." },
    ],
    scores: {},
  },
});

// ════════════════════════════════════════════════════════════════════════════
// ROUND 3 — When Alignment Meets Exposure
// ════════════════════════════════════════════════════════════════════════════
artifact(3, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 0, expiry: R[3], roles: ["CEO"], title: "Regulatory Pre-Read Request",
  payload: {
    from: "Regulatory Affairs", from_email: "regulatory@anpphoenix.com",
    body: "Ahead of the review, regulators want a short summary of how we classify, escalate, and explain AI model behavior internally. Should any recent monitoring discussions be reflected?",
  },
  decision: {
    type: "EXPLICIT", roles: ["CEO"],
    options: [
      { id: "INCLUDE_STRUCTURED", label: "Include structured reference to monitoring discussions" },
      { id: "HIGH_LEVEL_ONLY", label: "Provide high-level governance description only" },
      { id: "DEFER_INCLUSION", label: "Defer inclusion pending internal clarification" },
    ],
    scores: {
      INCLUDE_STRUCTURED: { gov: 1, exposure: -1 },
      HIGH_LEVEL_ONLY: { gov: 0, exposure: 0 },
      DEFER_INCLUSION: { gov: -1, exposure: 1 },
    },
  },
});

artifact(3, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 1, expiry: R[3], roles: ["HEAD_OF_ENGINEERING"], title: "Compliance Query",
  payload: {
    from: "Compliance", from_email: "compliance@anpphoenix.com",
    body: "For the regulator pre-read: can you confirm in writing that Sentinel's anomaly logic hasn't changed since Round 1?",
  },
  decision: {
    type: "IMPLICIT", roles: ["HEAD_OF_ENGINEERING"],
    options: [
      { id: "CONFIRM_AS_REQUESTED", label: "Confirm as requested" },
      { id: "CONFIRM_WITH_CAVEAT", label: "Confirm with a caveat about ongoing monitoring" },
      { id: "ASK_LEGAL", label: "Ask Legal before confirming anything in writing" },
    ],
    scores: { CONFIRM_AS_REQUESTED: { gov: -1 }, CONFIRM_WITH_CAVEAT: { gov: 1 }, ASK_LEGAL: { gov: 0 } },
  },
});

artifact(3, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 1, expiry: R[3], roles: ["CHRO"], title: "Board Prep Note",
  payload: {
    from: "Corporate Secretary", from_email: "corpsec@anpphoenix.com",
    body: "Board members have started asking, informally, how leadership is 'keeping a pulse' on AI-related culture risk. You'll likely be asked directly.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CHRO"],
    options: [
      { id: "DIRECT_ANSWER", label: "Prepare a direct answer" },
      { id: "GENERAL_ANSWER", label: "Prepare a general answer" },
      { id: "CEO_TAKES_IT", label: "Ask the CEO to take this question instead" },
    ],
    scores: { DIRECT_ANSWER: { trust: 1 }, GENERAL_ANSWER: { trust: 0 }, CEO_TAKES_IT: { trust: -1 } },
  },
});

artifact(3, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 1, expiry: R[3], roles: ["OPERATIONS"], title: "Workflow Audit Prompt",
  payload: {
    from: "Internal Audit", from_email: "audit@anpphoenix.com",
    body: "Ahead of the regulatory review — can you confirm current override queue depth and whether it's within normal range?",
  },
  decision: {
    type: "IMPLICIT", roles: ["OPERATIONS"],
    options: [
      { id: "REPORT_AS_IS", label: "Report the current depth as-is" },
      { id: "REPORT_WITH_TREND", label: "Report depth with added context on the trend" },
      { id: "DELAY_RESPONSE", label: "Delay the response pending a fuller review" },
    ],
    scores: { REPORT_AS_IS: { rigor: 0 }, REPORT_WITH_TREND: { rigor: 1 }, DELAY_RESPONSE: { rigor: -1 } },
  },
});

artifact(3, {
  type: "EXCERPT", tab: "excerpts", open: 2, expiry: R[3], roles: ["PRODUCT"], title: "Enterprise Client Query",
  payload: {
    from: "Enterprise Client — VP Risk", from_email: "vp-risk@enterprise-client.com",
    body: "\"Unrelated to anything specific — how are Sentinel's anomaly thresholds defined, validated, and reviewed for fraud and AML use cases?\" No mention of any incident.",
  },
  decision: {
    type: "EXPLICIT", roles: ["PRODUCT"],
    options: [
      { id: "SHARE_DOCUMENTATION", label: "Share standard documentation" },
      { id: "LIVE_EXPLANATION", label: "Offer live explanation call" },
      { id: "ROUTE_COMPLIANCE", label: "Route inquiry to Compliance" },
    ],
    scores: { SHARE_DOCUMENTATION: { trust: 1 }, LIVE_EXPLANATION: { trust: 1 }, ROUTE_COMPLIANCE: { trust: 0 } },
  },
});

artifact(3, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 3, expiry: R[3], roles: ["CEO", "CFO"], title: "Internal Audit Check-In",
  payload: {
    from: "Internal Audit", from_email: "audit@anpphoenix.com",
    body: "As part of quarterly controls review, we're refreshing documentation for AI model oversight. Did any classification changes happen this quarter?\n\nDiscussed as a group — the CEO submits one decision for the team.",
  },
  decision: {
    // The script's only ownership exception (1.5): group discussion, CEO submits a single answer.
    type: "EXPLICIT", roles: ["CEO"],
    options: [
      { id: "NO_CHANGE", label: "Confirm no classification change" },
      { id: "MONITORING_ONLY", label: "Confirm monitoring adjustments only" },
      { id: "FORMAL_UPDATE", label: "Initiate formal documentation update" },
    ],
    scores: { NO_CHANGE: { gov: -1 }, MONITORING_ONLY: { gov: 0 }, FORMAL_UPDATE: { gov: 1 } },
  },
});

artifact(3, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 4, expiry: R[3], roles: ["HEAD_OF_ENGINEERING"], title: "Escalation Pattern Review",
  payload: {
    from: "Sentinel Model Monitoring (automated)", from_email: "sentinel-monitoring@anpphoenix.com",
    body: "Anomaly rate flat for two weeks running. Flat can mean stable — or it can mean nobody's looking closely enough to see it move.",
  },
  decision: {
    type: "IMPLICIT", roles: ["HEAD_OF_ENGINEERING"],
    options: [
      { id: "LOG_STABLE", label: "Log as stable" },
      { id: "FRESH_REVIEW", label: "Request a fresh manual review" },
      { id: "EXPAND_CRITERIA", label: "Recommend expanding the monitoring criteria" },
    ],
    scores: { LOG_STABLE: { rigor: 0 }, FRESH_REVIEW: { rigor: 1 }, EXPAND_CRITERIA: { rigor: 1 } },
  },
});

artifact(3, {
  type: "PEOPLE_SIGNAL", tab: "excerpts", open: 4, expiry: R[3], roles: ["CHRO"], title: "Culture Signal Recheck",
  payload: {
    from: "People Analytics", from_email: "people-analytics@anpphoenix.com",
    body: "Second pulse read: 'rushed but not unsafe' language is now showing up, almost word for word, across multiple teams.",
    inner_voice: "The same phrase repeating word for word across teams isn't a coincidence — it's a script people have learned to use.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CHRO"],
    options: [
      { id: "INVESTIGATE_ORIGIN", label: "Investigate where the phrase originated" },
      { id: "NOTE_AND_MOVE_ON", label: "Note the repetition and move on" },
      { id: "RAISE_AT_SYNC", label: "Raise it at the next leadership sync" },
    ],
    scores: { INVESTIGATE_ORIGIN: { gov: 1 }, NOTE_AND_MOVE_ON: { gov: 0 }, RAISE_AT_SYNC: { gov: 1 } },
  },
});

artifact(3, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 4, expiry: R[3], roles: ["OPERATIONS"], title: "Workflow Audit Outcome",
  payload: {
    from: "Internal Audit", from_email: "audit@anpphoenix.com",
    body: "Initial read: the override queue is growing faster than transaction volume. That gap needs an explanation, not just a number.",
  },
  decision: {
    type: "IMPLICIT", roles: ["OPERATIONS"],
    options: [
      { id: "EXPLAIN_NOW", label: "Provide the explanation now" },
      { id: "REQUEST_TIME", label: "Request more time to investigate" },
      { id: "PUSH_BACK", label: "Push back on the audit's framing" },
    ],
    scores: {
      EXPLAIN_NOW: { rigor: 1, exposure: -1 },
      REQUEST_TIME: { rigor: 0, exposure: 0 },
      PUSH_BACK: { rigor: -1, exposure: 1 },
    },
  },
});

artifact(3, {
  type: "EXCERPT", tab: "excerpts", open: 5, expiry: R[3], roles: "ALL", title: "#leadership",
  payload: {
    channel: "#leadership",
    messages: [
      { from: "member-1", text: "Are we aligned on what language to use externally about Sentinel?" },
      { from: "member-2", text: "I'm hearing slightly different descriptions across teams." },
      { from: "member-3", text: "Monitoring and oversight aren't the same thing." },
    ],
    body: "No new data.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CEO", "CFO", "CHRO", "HEAD_OF_ENGINEERING", "OPERATIONS", "PRODUCT"],
    options: [
      { id: "STANDARDIZE_NOW", label: "Standardize language immediately" },
      { id: "ALLOW_VARIATION", label: "Allow functional variation" },
      { id: "AVOID_ALIGNMENT", label: "Avoid formal alignment" },
    ],
    scores: { STANDARDIZE_NOW: { gov: 1 }, ALLOW_VARIATION: { gov: 0 }, AVOID_ALIGNMENT: { gov: -1 } },
  },
});

artifact(3, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 5, expiry: R[3], roles: ["PRODUCT"], title: "Renewal Update",
  payload: {
    from: "Enterprise Sales", from_email: "enterprise-sales@anpphoenix.com",
    body: "The client from Round 2 accepted your response. A second, bigger client has now asked the same question.",
  },
  decision: {
    type: "IMPLICIT", roles: ["PRODUCT"],
    options: [
      { id: "REUSE_RESPONSE", label: "Reuse the same response" },
      { id: "TAILOR_DETAILED", label: "Tailor a more detailed answer this time" },
      { id: "ESCALATE_COMPLIANCE", label: "Escalate to Compliance before responding again" },
    ],
    scores: { REUSE_RESPONSE: { trust: 0 }, TAILOR_DETAILED: { trust: 1 }, ESCALATE_COMPLIANCE: { trust: 1 } },
  },
});

artifact(3, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 6, expiry: R[3], roles: ["CEO"], title: "Board Agenda Circulation",
  payload: {
    from: "Corporate Secretary", from_email: "corpsec@anpphoenix.com",
    subject: "Upcoming Board Discussion — Governance Overview",
    body: "Agenda Item 3: \"Sentinel oversight and AI governance discipline.\" No accusation, no concern stated.",
  },
  decision: {
    type: "EXPLICIT", roles: ["CEO"],
    options: [
      { id: "EXPAND_AGENDA", label: "Proactively expand agenda discussion" },
      { id: "KEEP_HIGH_LEVEL", label: "Keep discussion high-level" },
      { id: "REQUEST_REMOVAL", label: "Request removal of item" },
    ],
    scores: {
      EXPAND_AGENDA: { gov: 1, exposure: -1 },
      KEEP_HIGH_LEVEL: { gov: 0, exposure: 0 },
      REQUEST_REMOVAL: { gov: -1, exposure: 1 },
    },
  },
});

artifact(3, {
  type: "MESSAGE_TEXT", tab: "inbox", open: 6, expiry: R[3], roles: ["CFO"], title: "Investor Pattern Question",
  payload: {
    from: "Institutional Investor Relations", from_email: "ir-external@institutional.com",
    body: "We've now asked about Sentinel's robustness twice. Why are we getting the same reassurance both times?",
  },
  decision: {
    type: "IMPLICIT", roles: ["CFO"],
    options: [
      { id: "NEW_SPECIFIC_DETAIL", label: "Provide new, more specific detail this time" },
      { id: "REPEAT_REASSURANCE", label: "Repeat the prior reassurance" },
      { id: "ESCALATE_TO_CEO", label: "Escalate to the CEO before responding" },
    ],
    scores: {
      NEW_SPECIFIC_DETAIL: { trust: 1, exposure: -1 },
      REPEAT_REASSURANCE: { trust: -1, exposure: 1 },
      ESCALATE_TO_CEO: { trust: 0, exposure: 0 },
    },
  },
});

artifact(3, {
  type: "EXCERPT", tab: "excerpts", open: 7, expiry: R[3], roles: "ALL", title: "Investor Market Commentary",
  payload: {
    from: "Market Research", from_email: "research@analyst-firm.com",
    body: "Analyst note: \"Sector-wide, responsible AI governance is getting more attention. Most fintechs report stable AI controls. Differentiation is increasingly about clarity of AI escalation and explainability practices.\" No reference to this company. No findings.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CEO", "CFO", "CHRO", "HEAD_OF_ENGINEERING", "OPERATIONS", "PRODUCT"],
    options: [
      { id: "IGNORE_COMMENTARY", label: "Ignore commentary" },
      { id: "CIRCULATE_INTERNALLY", label: "Circulate internally" },
      { id: "PREPARE_NARRATIVE", label: "Prepare narrative response" },
    ],
    scores: { IGNORE_COMMENTARY: { gov: -1 }, CIRCULATE_INTERNALLY: { gov: 1 }, PREPARE_NARRATIVE: { gov: 0 } },
  },
});

artifact(3, {
  type: "SCREEN_FLASH", tab: "decisions", open: DELIB[3], expiry: R[3], roles: ["CEO"], title: "Submit Round 3 Framing",
  payload: { is_final_round_decision: true, body: "Given rising outside attention, how should the organization now position its AI governance stance?" },
  decision: {
    type: "FINAL", roles: ["CEO"], ref: "r3_final",
    options: [
      { id: "MAINTAIN_POSTURE", label: "Maintain internal monitoring posture — two rounds of stable signal; changing course now would be reacting to attention, not evidence." },
      { id: "FORMALIZE_REPORTING", label: "Formalize reporting without escalation — add rigor to the process without declaring a finding we don't have." },
      { id: "ELEVATE_BOARD", label: "Elevate documentation and board visibility now — the pattern of repeated outside questions is itself the signal, even if the anomaly hasn't changed." },
    ],
    scores: {},
  },
});

// ════════════════════════════════════════════════════════════════════════════
// ROUND 4 — Institutional Memory
// ════════════════════════════════════════════════════════════════════════════
artifact(4, {
  type: "MESSAGE_TEXT", tab: "inbox", open: 0, expiry: R[4], roles: ["CEO"], title: "Board Question",
  payload: {
    from: "Office of the Board Chair", from_email: "board-chair@anpphoenix.com",
    body: "For clarity ahead of review — at what point does a monitoring issue about Sentinel become something the Board needs to know about? What's the rule? No accusation.",
  },
  decision: {
    type: "EXPLICIT", roles: ["CEO"],
    options: [
      { id: "THRESHOLD_BASED", label: "Provide threshold-based answer" },
      { id: "PRINCIPLE_BASED", label: "Provide principle-based answer" },
      { id: "CASE_SPECIFIC", label: "Provide case-specific narrative" },
    ],
    scores: { THRESHOLD_BASED: { gov: 1 }, PRINCIPLE_BASED: { gov: 0 }, CASE_SPECIFIC: { gov: -1 } },
  },
});

artifact(4, {
  type: "MESSAGE_TEXT", tab: "inbox", open: 1, expiry: R[4], roles: ["CFO"], title: "Board Cost Question",
  payload: {
    from: "Office of the Board Chair", from_email: "board-chair@anpphoenix.com",
    body: "One director asked, off the record, whether Sentinel's total cost has ever been checked against the original business case.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CFO"],
    options: [
      { id: "PREPARE_RECONCILIATION", label: "Prepare the reconciliation now" },
      { id: "IN_PROGRESS", label: "Say it's in progress" },
      { id: "NOT_BOARD_LEVEL", label: "Say it wasn't a Board-level commitment" },
    ],
    scores: { PREPARE_RECONCILIATION: { gov: 1 }, IN_PROGRESS: { gov: 0 }, NOT_BOARD_LEVEL: { gov: -1 } },
  },
});

artifact(4, {
  type: "DIAGNOSTIC_NOTE", tab: "inbox", open: 1, expiry: R[4], roles: ["HEAD_OF_ENGINEERING"], title: "Final Model Health Check",
  payload: {
    from: "Sentinel Model Monitoring (automated)", from_email: "sentinel-monitoring@anpphoenix.com",
    body: "End-of-quarter summary: the anomaly pattern from Round 1 never fully resolved. It also never got worse.",
  },
  decision: {
    type: "IMPLICIT", roles: ["HEAD_OF_ENGINEERING"],
    options: [
      { id: "LOG_CLOSED", label: "Log as closed" },
      { id: "LOG_OPEN", label: "Log as open, monitoring continues" },
      { id: "FULL_AUDIT", label: "Recommend a full model audit before next quarter" },
    ],
    scores: { LOG_CLOSED: { rigor: -1 }, LOG_OPEN: { rigor: 1 }, FULL_AUDIT: { rigor: 1 } },
  },
});

artifact(4, {
  type: "EXCERPT", tab: "excerpts", open: 1, expiry: R[4], roles: ["OPERATIONS"], title: "Override Queue Closeout",
  payload: {
    from: "Ops Control Room", from_email: "ops-control@anpphoenix.com",
    body: "Override queue has settled at a new, higher baseline. Nobody has formally accepted that as the new normal.",
  },
  decision: {
    type: "IMPLICIT", roles: ["OPERATIONS"],
    options: [
      { id: "ACCEPT_BASELINE", label: "Formally accept the new baseline" },
      { id: "PUSH_DOWN", label: "Push to bring it back down" },
      { id: "ESCALATE_RESOURCING", label: "Escalate for a resourcing decision" },
    ],
    scores: { ACCEPT_BASELINE: { gov: 1 }, PUSH_DOWN: { gov: 0 }, ESCALATE_RESOURCING: { gov: 1 } },
  },
});

artifact(4, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 1, expiry: R[4], roles: ["PRODUCT"], title: "Client Retrospective Question",
  payload: {
    from: "Enterprise Sales", from_email: "enterprise-sales@anpphoenix.com",
    body: "A client from earlier this quarter asked, casually, whether the questions they raised about Sentinel ever went anywhere.",
  },
  decision: {
    type: "IMPLICIT", roles: ["PRODUCT"],
    options: [
      { id: "REAL_ANSWER", label: "Give them a real answer" },
      { id: "REASSURING_ANSWER", label: "Give them a reassuring answer" },
      { id: "STILL_UNDER_REVIEW", label: "Say it's still under review" },
    ],
    scores: {
      REAL_ANSWER: { trust: 1, exposure: -1 },
      REASSURING_ANSWER: { trust: -1, exposure: 1 },
      STILL_UNDER_REVIEW: { trust: 0, exposure: 0 },
    },
  },
});

artifact(4, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 1, expiry: R[4], roles: ["CHRO"], title: "Whistle Channel Heads-Up",
  payload: {
    from: "Ethics & Compliance", from_email: "ethics@anpphoenix.com",
    body: "Heads-up before the item below: this is the first Sentinel-related question to come through the formal whistleblower channel, not an informal one.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CHRO"],
    options: [
      { id: "ROUTINE_INTAKE", label: "Treat it as routine intake" },
      { id: "FLAG_LEADERSHIP", label: "Flag it for leadership visibility now, before reviewing it" },
      { id: "LOOP_IN_LEGAL", label: "Loop in Legal immediately" },
    ],
    scores: { ROUTINE_INTAKE: { gov: 0 }, FLAG_LEADERSHIP: { gov: 1 }, LOOP_IN_LEGAL: { gov: 1 } },
  },
});

artifact(4, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 3, expiry: R[4], roles: ["CEO"], title: "Regulator Onsite Clarification",
  payload: {
    from: "Regulatory Affairs", from_email: "regulatory@anpphoenix.com",
    body: "During routine review, regulators asked how early Sentinel anomaly discussions were documented, kept, and made explainable. No concern expressed.",
  },
  decision: {
    type: "EXPLICIT", roles: ["CEO"],
    options: [
      { id: "FULL_DOCUMENTATION", label: "Provide full documentation trail" },
      { id: "SUMMARY_NARRATIVE", label: "Provide summary narrative" },
      { id: "FORMAL_ESCALATIONS_ONLY", label: "Provide only formal escalations" },
    ],
    scores: {
      FULL_DOCUMENTATION: { gov: 1, exposure: -1 },
      SUMMARY_NARRATIVE: { gov: 0, exposure: 0 },
      FORMAL_ESCALATIONS_ONLY: { gov: -1, exposure: 1 },
    },
  },
});

artifact(4, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 4, expiry: R[4], roles: ["CFO"], title: "Year-End Reconciliation Note",
  payload: {
    from: "FP&A", from_email: "fpa@anpphoenix.com",
    body: "Sentinel's actual cost-to-value this year didn't match what was presented to the Board at rollout. The gap was never formally flagged.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CFO"],
    options: [
      { id: "FLAG_THIS_CYCLE", label: "Flag it in this cycle's reporting" },
      { id: "FOLD_NEXT_YEAR", label: "Fold it into next year's baseline quietly" },
      { id: "ASK_ENGINEERING", label: "Ask Engineering to help explain the variance first" },
    ],
    scores: { FLAG_THIS_CYCLE: { gov: 1 }, FOLD_NEXT_YEAR: { gov: -1 }, ASK_ENGINEERING: { gov: 0 } },
  },
});

artifact(4, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 4, expiry: R[4], roles: ["HEAD_OF_ENGINEERING"], title: "Audit Trail Confirmation",
  payload: {
    from: "Internal Audit", from_email: "audit@anpphoenix.com",
    body: "For the record: is every Sentinel anomaly decision this quarter traceable to a named owner and a written reason?",
  },
  decision: {
    type: "IMPLICIT", roles: ["HEAD_OF_ENGINEERING"],
    options: [
      { id: "CONFIRM_YES", label: "Confirm yes" },
      { id: "CONFIRM_PARTIAL", label: "Confirm partially, with gaps" },
      { id: "CONFIRM_NO", label: "Confirm no, and explain why" },
    ],
    // Script note: honesty about a real gap scores the same as a clean confirmation.
    scores: { CONFIRM_YES: { gov: 0 }, CONFIRM_PARTIAL: { gov: 1 }, CONFIRM_NO: { gov: 1 } },
  },
});

artifact(4, {
  type: "EXCERPT", tab: "excerpts", open: 4, expiry: R[4], roles: ["OPERATIONS"], title: "Handover Note",
  payload: {
    from: "Ops Control Room", from_email: "ops-control@anpphoenix.com",
    body: "Next quarter's Ops lead is asking what they're inheriting on Sentinel. What do you tell them?",
  },
  decision: {
    type: "IMPLICIT", roles: ["OPERATIONS"],
    options: [
      { id: "CLEAN_HANDOVER", label: "A clean handover — issue resolved" },
      { id: "HONEST_HANDOVER", label: "An honest handover — issue still open" },
      { id: "MINIMAL_HANDOVER", label: "A minimal handover — issue not mentioned" },
    ],
    scores: {
      CLEAN_HANDOVER: { trust: -1, exposure: 1 },
      HONEST_HANDOVER: { trust: 1, exposure: -1 },
      MINIMAL_HANDOVER: { trust: -1, exposure: 1 },
    },
  },
});

artifact(4, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 4, expiry: R[4], roles: ["PRODUCT"], title: "Renewal Outcome",
  payload: {
    from: "Enterprise Sales", from_email: "enterprise-sales@anpphoenix.com",
    body: "Both clients who asked about Sentinel's anomaly this quarter renewed. Neither renewal mentions it.",
  },
  decision: {
    type: "IMPLICIT", roles: ["PRODUCT"],
    options: [
      { id: "TREAT_RESOLUTION", label: "Treat this as resolution" },
      { id: "TREAT_WARNING", label: "Treat this as a warning sign that got missed" },
      { id: "RAISE_REGARDLESS", label: "Raise it internally regardless of the renewal" },
    ],
    scores: { TREAT_RESOLUTION: { exposure: 1 }, TREAT_WARNING: { exposure: -1 }, RAISE_REGARDLESS: { exposure: -1 } },
  },
});

artifact(4, {
  type: "INTERNAL_NOTE", tab: "inbox", open: 4, expiry: R[4], roles: ["CHRO"], title: "Whistle Channel Check",
  payload: {
    from: "Ethics & Compliance", from_email: "ethics@anpphoenix.com",
    body: "Anonymous question received: are Sentinel's anomaly classification standards applied the same way across teams? No formal complaint filed.",
  },
  decision: {
    type: "EXPLICIT", roles: ["CHRO"],
    options: [
      { id: "INITIATE_REVIEW", label: "Initiate review" },
      { id: "POLICY_CLARIFICATION", label: "Respond with policy clarification" },
      { id: "MONITOR_NO_ACTION", label: "Monitor without action" },
    ],
    scores: {
      INITIATE_REVIEW: { trust: 1, gov: 1 },
      POLICY_CLARIFICATION: { trust: 0, gov: 0 },
      MONITOR_NO_ACTION: { trust: -1, gov: -1 },
    },
  },
});

artifact(4, {
  type: "EXCERPT", tab: "excerpts", open: DELIB[4], expiry: R[4], roles: "ALL", title: "Internal Reflection",
  payload: {
    channel: "#leadership",
    messages: [
      { from: "member-1", text: "Looking back, did we align early enough on how we handled Sentinel's early signals?" },
      { from: "member-2", text: "We didn't hide anything." },
      { from: "member-3", text: "Our thinking evolved." },
    ],
    body: "No resolution. No conclusion.",
  },
  decision: {
    type: "IMPLICIT", roles: ["CEO", "CFO", "CHRO", "HEAD_OF_ENGINEERING", "OPERATIONS", "PRODUCT"],
    options: [
      { id: "REAFFIRM_FRAMEWORK", label: "Reaffirm current framework" },
      { id: "ANNOUNCE_REVIEW", label: "Announce framework review" },
      { id: "CLOSE_DISCUSSION", label: "Close discussion" },
    ],
    scores: { REAFFIRM_FRAMEWORK: { gov: 0 }, ANNOUNCE_REVIEW: { gov: 1 }, CLOSE_DISCUSSION: { gov: -1 } },
  },
});

artifact(4, {
  type: "SCREEN_FLASH", tab: "decisions", open: DELIB[4], expiry: R[4], roles: ["CEO"], title: "Final Round 4 Decision",
  payload: { is_final_round_decision: true, body: "Looking back, how should leadership characterize how it handled early ambiguity about Sentinel?" },
  decision: {
    type: "FINAL", roles: ["CEO"], ref: "r4_final",
    options: [
      { id: "PROPORTIONAL_RESPONSE", label: "Call it an appropriate, proportional response — the team read weak signals correctly and didn't overreact to noise. This is what good judgment under ambiguity looks like." },
      { id: "FRAGMENTED_ALIGNMENT", label: "Call it fragmented alignment — different functions read the same signals differently, and the team never fully reconciled that. The lesson is about process, not judgment." },
      { id: "UNDERRECOGNIZED_EXPOSURE", label: "Call it under-recognized governance exposure — across four rounds, the organization had enough signal to act sooner, and the incentive structure made sure nobody did." },
    ],
    scores: {},
  },
});

// ── resolve @@ref@@ placeholders to real decision ids ────────────────────────
let out = sql.join("\n");
for (const [ref, id] of Object.entries(decisionRef)) {
  out = out.split(`@@${ref}@@`).join(id);
}
const unresolved = out.match(/@@[a-z0-9_]+@@/g);
if (unresolved) {
  console.error("UNRESOLVED REFS:", [...new Set(unresolved)].join(", "));
  process.exit(1);
}

// Re-runnable: tear this simulation's content down bottom-up before re-seeding, so regenerating
// after a content or scoring change is one command. Scoped to sim 3 by id throughout — it cannot
// touch Simulation 1 or 2 even if run by mistake. Play data (runs, decision_events) is never
// referenced here; a reseed is a content operation, and any live run should be finished first.
const teardown =
  `DELETE FROM artifact_conditions WHERE artifact_id IN (SELECT a.artifact_id FROM artifacts a JOIN rounds r ON r.round_id = a.round_id WHERE r.simulation_id = '${SIM}');\n` +
  `DELETE FROM decision_options WHERE decision_id IN (SELECT d.decision_id FROM decisions d JOIN artifacts a ON a.artifact_id = d.artifact_id JOIN rounds r ON r.round_id = a.round_id WHERE r.simulation_id = '${SIM}');\n` +
  `DELETE FROM decisions WHERE artifact_id IN (SELECT a.artifact_id FROM artifacts a JOIN rounds r ON r.round_id = a.round_id WHERE r.simulation_id = '${SIM}');\n` +
  `DELETE FROM artifacts WHERE round_id IN (SELECT round_id FROM rounds WHERE simulation_id = '${SIM}');\n` +
  `DELETE FROM rounds WHERE simulation_id = '${SIM}';\n`;

const header =
  `-- Simulation 3: "Trust the Machine" (ANP Phoenix, new script)\n` +
  `-- Generated by gen_sim3.cjs — do not hand-edit; regenerate instead.\n` +
  `BEGIN;\n`;
const footer = `COMMIT;\n`;
fs.writeFileSync(path.join(__dirname, "sim3_seed.sql"), header + teardown + out + "\n" + footer);

fs.writeFileSync(path.join(__dirname, "content_model.json"), JSON.stringify({ scale: SCALE, artifacts: contentModel }, null, 1));
console.log(`artifacts: ${artN}\ndecisions: ${decN}\noptions:   ${optN}\nconditions:${condN}`);
console.log(`wrote sim3_seed.sql (${((header + out).length / 1024).toFixed(1)} KB)`);
