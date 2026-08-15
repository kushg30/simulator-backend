// End-to-end backend test for Meridian QBR v4, against the live Render backend.
const BASE = "https://simulator-backend-7xvh.onrender.com";
const SIM = "5116d200-0000-4000-a000-000000000002";
const LEAD = "TEAM_LEAD";
const OWNER = {
  1: "DATA_QUALITY_ANALYST", 2: "CATEGORY_REGIONAL_ANALYST",
  3: "REPORTING_DASHBOARD_ANALYST", 4: "PEOPLE_ANALYTICS_ASSOCIATE", 5: "TEAM_LEAD",
};
const ANSWERS = {
  1: "62667 | issues: Improper Formatting, Incomplete, Duplicated | note: 5 dup pairs, 62667 is trustworthy",
  2: "People (Training & Skill Gap); 25.5 | note: West 3.5 training hrs vs 15.75 elsewhere, a 25.5pp gap",
  3: "270; 1381546 | macro: Yes | note: recorded a macro to combine both months, 270 rows",
  4: "Notebook Set; 35; April; 90 | chart: Bar chart",
  5: "| situation: The Board wants a QBR it can trust | complication: revenue is 62,667 once duplicates are removed; the West shortfall is a People/training gap of 25.5; the combined file is 270 rows and 1,381,546 revenue; Notebook Set peaks in April | question: where should the Board invest next | answer: fix the data pipeline and close the training gap",
};

let pass = 0, fail = 0;
const log = (ok, msg, extra = "") => { console.log(`${ok ? "  PASS" : "✗ FAIL"}  ${msg}${extra ? "  — " + extra : ""}`); ok ? pass++ : fail++; };

async function j(method, path, body, form = false) {
  const opt = { method, headers: {} };
  if (body && form) { opt.headers["Content-Type"] = "application/x-www-form-urlencoded"; opt.body = new URLSearchParams(body).toString(); }
  else if (body) { opt.headers["Content-Type"] = "application/json"; opt.body = JSON.stringify(body); }
  const res = await fetch(BASE + path, opt);
  const text = await res.text();
  let data; try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { status: res.status, ok: res.ok, data };
}

async function main() {
  console.log("── Warming backend (Render cold start can take ~50s) ──");
  for (let i = 0; i < 12; i++) {
    try { const r = await fetch(BASE + "/api/teams/00000000-0000-0000-0000-000000000000/roles"); if (r.status) break; } catch {}
    await new Promise(r => setTimeout(r, 5000));
  }

  const stamp = "E2E" + Date.now().toString().slice(-6);
  console.log(`\n── 1. Create team ${stamp} (creator = lead) ──`);
  const c = await j("POST", "/api/teams", { teamName: stamp, participantName: "Lead", simulationId: SIM });
  log(c.ok && c.data?.teamId, "create team", c.ok ? `role=${c.data.role}` : JSON.stringify(c.data));
  const teamId = c.data.teamId;
  const P = { [LEAD]: c.data.participantId };

  console.log("\n── 2. Join four members ──");
  for (const label of ["m2", "m3", "m4", "m5"]) {
    const jr = await j("POST", `/api/teams/${teamId}/join`, { participantName: label });
    log(jr.ok && jr.data?.participantId, `join ${label}`, jr.ok ? "" : JSON.stringify(jr.data));
    P["_" + label] = jr.data.participantId;
  }

  console.log("\n── 3. Assign the four non-lead roles ──");
  const assign = [
    ["_m2", "DATA_QUALITY_ANALYST"], ["_m3", "CATEGORY_REGIONAL_ANALYST"],
    ["_m4", "REPORTING_DASHBOARD_ANALYST"], ["_m5", "PEOPLE_ANALYTICS_ASSOCIATE"],
  ];
  for (const [k, role] of assign) {
    const a = await j("POST", `/api/teams/${teamId}/assign-role`, { participantId: P["_" + k.slice(1)], role });
    log(a.ok, `assign ${role}`, a.ok ? "" : JSON.stringify(a.data));
    P[role] = P["_" + k.slice(1)];
  }

  console.log("\n── 4. Roles map shows 5 filled ──");
  const roles = await j("GET", `/api/teams/${teamId}/roles`);
  const filled = roles.data && Object.values(roles.data).filter(Boolean).length;
  log(filled === 5, "5 of 5 roles filled", `filled=${filled}, keys=${Object.keys(roles.data || {}).length}`);

  console.log("\n── 5. Start run ──");
  const run = await j("POST", `/api/runs/start/${teamId}`);
  log(run.ok && run.data?.runId, "start run", run.ok ? "" : JSON.stringify(run.data));
  const runId = run.data.runId;

  // Negative test: a non-owner, non-lead tries to submit round 1 -> must be rejected.
  console.log("\n── 6. Round lifecycle 1..5 ──");
  for (let n = 1; n <= 5; n++) {
    const st = await j("POST", `/api/sim2/runs/${runId}/rounds/${n}/start`);
    log(st.ok, `R${n} start`, st.ok ? "" : JSON.stringify(st.data));

    if (n === 1) {
      const badRole = "PEOPLE_ANALYTICS_ASSOCIATE"; // not the R1 owner, not lead
      const bad = await j("POST", `/api/sim2/runs/${runId}/rounds/1/submission`,
        { participantId: P[badRole], typedAnswer: "62667; 59", confidence: "HIGH" }, true);
      log(!bad.ok, "R1 rejects a non-owner/non-lead submitter", bad.ok ? "WRONGLY ACCEPTED" : `(${bad.data?.error || bad.status})`);
    }

    const ownerRole = OWNER[n];
    const sub = await j("POST", `/api/sim2/runs/${runId}/rounds/${n}/submission`,
      { participantId: P[ownerRole], typedAnswer: ANSWERS[n], confidence: "HIGH" }, true);
    log(sub.ok, `R${n} owner (${ownerRole}) submits`, sub.ok ? "" : `(${sub.data?.error || sub.status})`);

    const res = await j("GET", `/api/sim2/runs/${runId}/rounds/${n}/results`);
    const correct = res.data?.submission?.isCorrect;
    if (n === 5) {
      // v5: Round 5 is a free-text SCQA synthesis — not correct/incorrect.
      log(correct === null || correct === undefined, "R5 synthesis accepted (not numerically graded)", `isCorrect=${correct}, next=${res.data?.nextRound}`);
    } else {
      log(correct === true, `R${n} graded correct`, `isCorrect=${correct}, next=${res.data?.nextRound}`);
    }
  }

  console.log("\n── 7. Final scores (round 0) ──");
  const fin = await j("GET", `/api/sim2/runs/${runId}/rounds/5/results`);
  const reveal = fin.data?.finalReveal || [];
  log(reveal.length >= 5, "final reveal has 5 constructs", `count=${reveal.length}`);
  for (const c of reveal) console.log(`      ${c.construct.padEnd(22)} ${String(c.value).padStart(4)}  ${c.status}  — ${(c.detail||"").slice(0,70)}`);

  console.log(`\n══ RESULT: ${pass} passed, ${fail} failed ══`);
  console.log(`(test team ${stamp} / run ${runId} — terminate after)`);
  console.log("RUNID=" + runId + " TEAMID=" + teamId);
}
main().catch(e => { console.error("FATAL", e); process.exit(1); });
