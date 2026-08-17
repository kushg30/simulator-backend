// v6 facilitator Round Restart: undo an accidental submission.
const BASE = "https://simulator-backend-7xvh.onrender.com";
const SIM = "5116d200-0000-4000-a000-000000000002";
const TOKEN = process.env.FTOKEN || "meridian-facilitator-2026";
let pass = 0, fail = 0;
const log = (ok, m, x = "") => { console.log(`${ok ? "  PASS" : "✗ FAIL"}  ${m}${x ? "  — " + x : ""}`); ok ? pass++ : fail++; };
async function j(method, path, body, form = false, faculty = false) {
  const opt = { method, headers: {} };
  if (faculty) opt.headers["X-Faculty-Token"] = TOKEN;
  if (body && form) { opt.headers["Content-Type"] = "application/x-www-form-urlencoded"; opt.body = new URLSearchParams(body).toString(); }
  else if (body) { opt.headers["Content-Type"] = "application/json"; opt.body = JSON.stringify(body); }
  const res = await fetch(BASE + path, opt); const t = await res.text();
  let d; try { d = t ? JSON.parse(t) : null; } catch { d = t; }
  return { ok: res.ok, status: res.status, data: d };
}
const state = async (runId, n) => { const r = await j("GET", `/api/sim2/runs/${runId}/state`); return (r.data || []).find(s => s.roundNumber === n)?.status; };

async function main() {
  for (let i = 0; i < 15; i++) { const r = await fetch(BASE + "/api/teams/00000000-0000-0000-0000-000000000000/roles"); if (r.status) break; await new Promise(r => setTimeout(r, 4000)); }
  const c = await j("POST", "/api/teams", { teamName: "RST" + Date.now().toString().slice(-5), participantName: "Lead", simulationId: SIM });
  const teamId = c.data.teamId; const P = { TEAM_LEAD: c.data.participantId };
  for (const [n, role] of [["m2", "DATA_QUALITY_ANALYST"], ["m3", "CATEGORY_REGIONAL_ANALYST"], ["m4", "REPORTING_DASHBOARD_ANALYST"], ["m5", "PEOPLE_ANALYTICS_ASSOCIATE"]]) { const jr = await j("POST", `/api/teams/${teamId}/join`, { participantName: n }); await j("POST", `/api/teams/${teamId}/assign-role`, { participantId: jr.data.participantId, role }); P[role] = jr.data.participantId; }
  const run = await j("POST", `/api/runs/start/${teamId}`); const runId = run.data.runId;
  console.log(`run ${runId}\n`);

  await j("POST", `/api/sim2/runs/${runId}/rounds/1/start`);
  await j("POST", `/api/sim2/runs/${runId}/rounds/1/submission`, { participantId: P.DATA_QUALITY_ANALYST, typedAnswer: "62667 | issues: Improper Formatting, Incomplete, Duplicated | note: ok", confidence: "HIGH" }, true);
  await j("POST", `/api/sim2/runs/${runId}/rounds/2/start`);
  // Accidental (wrong) R2 submission
  await j("POST", `/api/sim2/runs/${runId}/rounds/2/submission`, { participantId: P.CATEGORY_REGIONAL_ANALYST, typedAnswer: "Market (External Demand Condition); 9 | note: oops submitted early", confidence: "LOW" }, true);
  log(await state(runId, 2) === "COMPLETE", "R2 submitted (COMPLETE) before restart", "state=" + await state(runId, 2));

  // Facilitator restarts the last submitted round (R2)
  const rst = await j("POST", `/api/faculty/runs/${runId}/restart-last-round`, { note: "student mis-submitted", actor: "tester" }, false, true);
  log(rst.ok && rst.data?.roundNumber === 2, "restart-last-round re-opens R2", rst.ok ? JSON.stringify(rst.data) : `(${rst.status} ${JSON.stringify(rst.data)})`);
  log(await state(runId, 2) === "ACTIVE", "R2 is ACTIVE again after restart", "state=" + await state(runId, 2));

  // The team re-submits R2 correctly
  const re = await j("POST", `/api/sim2/runs/${runId}/rounds/2/submission`, { participantId: P.CATEGORY_REGIONAL_ANALYST, typedAnswer: "People (Training & Skill Gap); 25.5 | note: 25.5 gap this time", confidence: "HIGH" }, true);
  log(re.ok, "R2 can be re-submitted after restart", re.ok ? "" : `(${re.data?.error})`);
  const res2 = await j("GET", `/api/sim2/runs/${runId}/rounds/2/results`);
  log(res2.data?.submission?.outcomePct === 100, "re-submitted R2 now scores 100%", "outcome=" + res2.data?.submission?.outcomePct);

  console.log(`\n══ RESULT: ${pass} passed, ${fail} failed ══`);
}
main().catch(e => { console.error("FATAL", e); process.exit(1); });
