// Negative-path E2E: wrong answers, judgment penalty, double-submit guard, lead fallback.
const BASE = "https://simulator-backend-7xvh.onrender.com";
const SIM = "5116d200-0000-4000-a000-000000000002";
let pass = 0, fail = 0;
const log = (ok, msg, extra = "") => { console.log(`${ok ? "  PASS" : "✗ FAIL"}  ${msg}${extra ? "  — " + extra : ""}`); ok ? pass++ : fail++; };
async function j(method, path, body, form = false) {
  const opt = { method, headers: {} };
  if (body && form) { opt.headers["Content-Type"] = "application/x-www-form-urlencoded"; opt.body = new URLSearchParams(body).toString(); }
  else if (body) { opt.headers["Content-Type"] = "application/json"; opt.body = JSON.stringify(body); }
  const res = await fetch(BASE + path, opt); const text = await res.text();
  let data; try { data = text ? JSON.parse(text) : null; } catch { data = text; }
  return { status: res.status, ok: res.ok, data };
}
const jc = (results, name) => (results?.constructs || []).find(c => c.construct === name)?.value;

async function main() {
  const stamp = "NEG" + Date.now().toString().slice(-6);
  const c = await j("POST", "/api/teams", { teamName: stamp, participantName: "Lead", simulationId: SIM });
  const teamId = c.data.teamId; const lead = c.data.participantId; const P = {};
  for (const label of ["m2", "m3", "m4", "m5"]) { const r = await j("POST", `/api/teams/${teamId}/join`, { participantName: label }); P[label] = r.data.participantId; }
  const roles = [["m2","DATA_QUALITY_ANALYST"],["m3","CATEGORY_REGIONAL_ANALYST"],["m4","REPORTING_DASHBOARD_ANALYST"],["m5","PEOPLE_ANALYTICS_ASSOCIATE"]];
  for (const [k, role] of roles) { await j("POST", `/api/teams/${teamId}/assign-role`, { participantId: P[k], role }); P[role] = P[k]; }
  const run = await j("POST", `/api/runs/start/${teamId}`); const runId = run.data.runId;
  console.log(`Team ${stamp} run ${runId}\n`);

  // v5 strict ownership: the Team Lead is NOT the R1 owner (DQA is) -> rejected.
  await j("POST", `/api/sim2/runs/${runId}/rounds/1/start`);
  const leadTry = await j("POST", `/api/sim2/runs/${runId}/rounds/1/submission`,
    { participantId: lead, typedAnswer: "62667", confidence: "HIGH" }, true);
  log(!leadTry.ok, "R1 rejects the Team Lead (strict owner-only)", leadTry.ok ? "WRONGLY ACCEPTED" : `(${leadTry.data?.error})`);

  // Owner (DQA) submits a WRONG answer at HIGH confidence.
  const s1 = await j("POST", `/api/sim2/runs/${runId}/rounds/1/submission`,
    { participantId: P.DATA_QUALITY_ANALYST, typedAnswer: "99999 | issues: Incorrect | note: rushed", confidence: "HIGH" }, true);
  log(s1.ok, "R1 owner submits (wrong answer)", s1.ok ? "" : JSON.stringify(s1.data));

  // Double submit must be rejected.
  const dup = await j("POST", `/api/sim2/runs/${runId}/rounds/1/submission`,
    { participantId: P.DATA_QUALITY_ANALYST, typedAnswer: "62667", confidence: "LOW" }, true);
  log(!dup.ok, "R1 double-submit rejected", dup.ok ? "WRONGLY ACCEPTED" : `(${dup.data?.error})`);

  const r1 = await j("GET", `/api/sim2/runs/${runId}/rounds/1/results`);
  log(r1.data?.submission?.isCorrect === false, "R1 wrong answer graded incorrect", `isCorrect=${r1.data?.submission?.isCorrect}`);
  log(jc(r1.data, "JUDGMENT_CALIBRATION") === 0, "R1 Judgment = 0 (wrong + HIGH)", `judg=${jc(r1.data, "JUDGMENT_CALIBRATION")}`);
  log(jc(r1.data, "ANALYTICAL_RIGOR") === 0, "R1 Analytical Rigor = 0 (wrong)", `rigor=${jc(r1.data, "ANALYTICAL_RIGOR")}`);

  // R2: owner submits WRONG root cause at LOW confidence -> Judgment should be 40.
  await j("POST", `/api/sim2/runs/${runId}/rounds/2/start`);
  await j("POST", `/api/sim2/runs/${runId}/rounds/2/submission`,
    { participantId: P.CATEGORY_REGIONAL_ANALYST, typedAnswer: "Market (Environment / Demand); 10 | note: guess", confidence: "LOW" }, true);
  const r2 = await j("GET", `/api/sim2/runs/${runId}/rounds/2/results`);
  log(r2.data?.submission?.isCorrect === false, "R2 wrong answer graded incorrect", `isCorrect=${r2.data?.submission?.isCorrect}`);
  log(jc(r2.data, "JUDGMENT_CALIBRATION") === 40, "R2 Judgment = 40 (wrong + LOW)", `judg=${jc(r2.data, "JUDGMENT_CALIBRATION")}`);

  // R3: owner submits the 264 trap -> incorrect.
  await j("POST", `/api/sim2/runs/${runId}/rounds/3/start`);
  await j("POST", `/api/sim2/runs/${runId}/rounds/3/submission`,
    { participantId: P.REPORTING_DASHBOARD_ANALYST, typedAnswer: "264; 1381546 | macro: Yes | note: removed dups", confidence: "MEDIUM" }, true);
  const r3 = await j("GET", `/api/sim2/runs/${runId}/rounds/3/results`);
  log(r3.data?.submission?.isCorrect === false, "R3 '264' trap graded incorrect", `isCorrect=${r3.data?.submission?.isCorrect}`);

  console.log(`\n══ RESULT: ${pass} passed, ${fail} failed ══`);
  console.log("RUNID=" + runId + " TEAMID=" + teamId);
}
main().catch(e => { console.error("FATAL", e); process.exit(1); });
