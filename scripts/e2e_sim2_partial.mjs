// v6 partial-credit checks: a round is 0-100%, not all-or-nothing.
const BASE = "https://simulator-backend-7xvh.onrender.com";
const SIM = "5116d200-0000-4000-a000-000000000002";
let pass = 0, fail = 0;
const log = (ok, m, x = "") => { console.log(`${ok ? "  PASS" : "✗ FAIL"}  ${m}${x ? "  — " + x : ""}`); ok ? pass++ : fail++; };
async function j(method, path, body, form = false) {
  const opt = { method, headers: {} };
  if (body && form) { opt.headers["Content-Type"] = "application/x-www-form-urlencoded"; opt.body = new URLSearchParams(body).toString(); }
  else if (body) { opt.headers["Content-Type"] = "application/json"; opt.body = JSON.stringify(body); }
  const res = await fetch(BASE + path, opt); const t = await res.text();
  let d; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: res.ok, status: res.status, data: d };
}
async function setup() {
  for (let i = 0; i < 15; i++) { const r = await fetch(BASE + "/api/teams/00000000-0000-0000-0000-000000000000/roles"); if (r.status) break; await new Promise(r => setTimeout(r, 4000)); }
  const c = await j("POST", "/api/teams", { teamName: "PART" + Date.now().toString().slice(-5), participantName: "Lead", simulationId: SIM });
  const teamId = c.data.teamId; const P = { TEAM_LEAD: c.data.participantId };
  const R = [["m2", "DATA_QUALITY_ANALYST"], ["m3", "CATEGORY_REGIONAL_ANALYST"], ["m4", "REPORTING_DASHBOARD_ANALYST"], ["m5", "PEOPLE_ANALYTICS_ASSOCIATE"]];
  for (const [n, role] of R) { const jr = await j("POST", `/api/teams/${teamId}/join`, { participantName: n }); await j("POST", `/api/teams/${teamId}/assign-role`, { participantId: jr.data.participantId, role }); P[role] = jr.data.participantId; }
  const run = await j("POST", `/api/runs/start/${teamId}`);
  return { runId: run.data.runId, P };
}
async function outcome(runId, n) { const r = await j("GET", `/api/sim2/runs/${runId}/rounds/${n}/results`); return r.data?.submission?.outcomePct; }

async function main() {
  const { runId, P } = await setup();
  console.log(`run ${runId}\n`);

  // R1: correct revenue (62667) but only TWO of three tags -> 70 + 15 = 85%.
  await j("POST", `/api/sim2/runs/${runId}/rounds/1/start`);
  await j("POST", `/api/sim2/runs/${runId}/rounds/1/submission`,
    { participantId: P.DATA_QUALITY_ANALYST, typedAnswer: "62667 | issues: Improper Formatting, Incomplete | note: found two issue types, revenue is 62667", confidence: "HIGH" }, true);
  log(await outcome(runId, 1) === 85, "R1 correct revenue + 2/3 tags = 85% (partial)", "outcome=" + await outcome(runId, 1));

  // R2: correct root cause (People) but wrong gap -> 50%.
  await j("POST", `/api/sim2/runs/${runId}/rounds/2/start`);
  await j("POST", `/api/sim2/runs/${runId}/rounds/2/submission`,
    { participantId: P.CATEGORY_REGIONAL_ANALYST, typedAnswer: "People (Training & Skill Gap); 12 | note: training gap of 12", confidence: "MEDIUM" }, true);
  log(await outcome(runId, 2) === 50, "R2 People + wrong gap = 50% (partial)", "outcome=" + await outcome(runId, 2));

  // R3: right rows (270) but wrong revenue -> 50%.
  await j("POST", `/api/sim2/runs/${runId}/rounds/3/start`);
  await j("POST", `/api/sim2/runs/${runId}/rounds/3/submission`,
    { participantId: P.REPORTING_DASHBOARD_ANALYST, typedAnswer: "270; 999999 | macro: Yes | note: recorded a macro to combine", confidence: "LOW" }, true);
  log(await outcome(runId, 3) === 50, "R3 right rows + wrong revenue = 50% (partial)", "outcome=" + await outcome(runId, 3));

  // R4: 3 of 4 fields right (wrong month count) -> 75%.
  await j("POST", `/api/sim2/runs/${runId}/rounds/4/start`);
  await j("POST", `/api/sim2/runs/${runId}/rounds/4/submission`,
    { participantId: P.PEOPLE_ANALYTICS_ASSOCIATE, typedAnswer: "Notebook Set; 35; April; 77 | tool: Power BI | chart: Bar Chart", confidence: "HIGH" }, true);
  log(await outcome(runId, 4) === 75, "R4 three of four fields = 75% (partial)", "outcome=" + await outcome(runId, 4));

  console.log(`\n══ RESULT: ${pass} passed, ${fail} failed ══  (run ${runId})`);
}
main().catch(e => { console.error("FATAL", e); process.exit(1); });
