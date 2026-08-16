// v6 Round 2 Breaking-News confidence-revision modifier.
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
async function team() {
  for (let i = 0; i < 15; i++) { const r = await fetch(BASE + "/api/teams/00000000-0000-0000-0000-000000000000/roles"); if (r.status) break; await new Promise(r => setTimeout(r, 4000)); }
  const c = await j("POST", "/api/teams", { teamName: "REV" + Date.now().toString().slice(-5), participantName: "Lead", simulationId: SIM });
  const teamId = c.data.teamId; const P = { TEAM_LEAD: c.data.participantId };
  for (const [n, role] of [["m2", "DATA_QUALITY_ANALYST"], ["m3", "CATEGORY_REGIONAL_ANALYST"], ["m4", "REPORTING_DASHBOARD_ANALYST"], ["m5", "PEOPLE_ANALYTICS_ASSOCIATE"]]) { const jr = await j("POST", `/api/teams/${teamId}/join`, { participantName: n }); await j("POST", `/api/teams/${teamId}/assign-role`, { participantId: jr.data.participantId, role }); P[role] = jr.data.participantId; }
  const run = await j("POST", `/api/runs/start/${teamId}`);
  return { runId: run.data.runId, P };
}
const judg = async (runId) => { const r = await j("GET", `/api/sim2/runs/${runId}/rounds/2/results`); return (r.data?.constructs || []).find(c => c.construct === "JUDGMENT_CALIBRATION")?.value; };

async function run(r2answer, label, revise) {
  const { runId, P } = await team();
  await j("POST", `/api/sim2/runs/${runId}/rounds/1/start`);
  await j("POST", `/api/sim2/runs/${runId}/rounds/1/submission`, { participantId: P.DATA_QUALITY_ANALYST, typedAnswer: "62667 | issues: Improper Formatting, Incomplete, Duplicated | note: ok 62667", confidence: "HIGH" }, true);
  await j("POST", `/api/sim2/runs/${runId}/rounds/2/start`);
  await j("POST", `/api/sim2/runs/${runId}/rounds/2/submission`, { participantId: P.CATEGORY_REGIONAL_ANALYST, typedAnswer: r2answer, confidence: "HIGH" }, true);
  const before = await judg(runId);
  let after = before;
  if (revise) { await j("POST", `/api/sim2/runs/${runId}/rounds/2/revise-confidence`, { confidence: revise }); after = await judg(runId); }
  return { before, after, runId };
}

async function main() {
  // Wrong root cause (Market) + HIGH -> base Judgment 0. Revise down to LOW -> 40 + 15 = 55.
  const a = await run("Market (External Demand Condition); 10 | note: guess", "wrong+HIGH", "LOW");
  log(a.before === 0, "R2 wrong + HIGH => Judgment 0 (base)", "before=" + a.before);
  log(a.after === 55, "R2 wrong, revised HIGH->LOW => 40 + 15 modifier = 55", "after=" + a.after);

  // Correct root cause (People) + right gap + HIGH -> 100. Revise down to LOW -> base 60, no modifier (correct).
  const b = await run("People (Training & Skill Gap); 25.5 | note: 25.5 gap", "correct+HIGH", "LOW");
  log(b.before === 100, "R2 correct + HIGH => Judgment 100 (base)", "before=" + b.before);
  log(b.after === 60, "R2 correct, revised HIGH->LOW => base 60, no modifier", "after=" + b.after);

  console.log(`\n══ RESULT: ${pass} passed, ${fail} failed ══`);
}
main().catch(e => { console.error("FATAL", e); process.exit(1); });
