// Load test: 10 teams playing Meridian QBR v5 simultaneously, with 50 clients
// polling round-state/artifacts throughout — mirrors a live class of ~50 students.
const BASE = "https://simulator-backend-7xvh.onrender.com";
const SIM = "5116d200-0000-4000-a000-000000000002";
const TEAMS = 10;
const OWNER = { 1: "DATA_QUALITY_ANALYST", 2: "CATEGORY_REGIONAL_ANALYST",
  3: "REPORTING_DASHBOARD_ANALYST", 4: "PEOPLE_ANALYTICS_ASSOCIATE", 5: "TEAM_LEAD" };
const NONLEAD = ["DATA_QUALITY_ANALYST", "CATEGORY_REGIONAL_ANALYST", "REPORTING_DASHBOARD_ANALYST", "PEOPLE_ANALYTICS_ASSOCIATE"];
const ANS = {
  1: "62667 | issues: Improper Formatting, Incomplete, Duplicated | note: dup pairs found",
  2: "People (Training & Skill Gap); 25.5 | note: training gap",
  3: "270; 1381546 | macro: Yes | note: recorded macro",
  4: "Notebook Set; 35; April; 90 | chart: Bar chart",
  5: "| situation: s | complication: 62667 duplicate People 25.5 270 1381546 macro Notebook Set April | question: q | answer: a",
};

const lat = []; let reqs = 0, errs = 0;
const errKinds = {};
async function req(method, path, body, form = false) {
  const t0 = Date.now();
  const opt = { method, headers: {} };
  if (body && form) { opt.headers["Content-Type"] = "application/x-www-form-urlencoded"; opt.body = new URLSearchParams(body).toString(); }
  else if (body) { opt.headers["Content-Type"] = "application/json"; opt.body = JSON.stringify(body); }
  reqs++;
  try {
    const res = await fetch(BASE + path, opt);
    const txt = await res.text();
    lat.push(Date.now() - t0);
    let data; try { data = txt ? JSON.parse(txt) : null; } catch { data = txt; }
    if (!res.ok) { errs++; errKinds[res.status] = (errKinds[res.status] || 0) + 1; }
    return { ok: res.ok, status: res.status, data };
  } catch (e) {
    lat.push(Date.now() - t0); errs++; errKinds["net"] = (errKinds["net"] || 0) + 1;
    return { ok: false, status: 0, data: String(e) };
  }
}

const sleep = (ms) => new Promise(r => setTimeout(r, ms));
let polling = true;
// Each simulated client polls the two hot read endpoints on a jittered interval.
async function pollClient(runId, pid, getRound) {
  while (polling) {
    await req("GET", `/api/sim2/runs/${runId}/state`);
    await req("GET", `/api/sim2/runs/${runId}/rounds/${getRound()}/participants/${pid}/artifacts`);
    await req("GET", `/api/sim2/runs/${runId}/broadcast`);
    await sleep(3500 + Math.random() * 1500);
  }
}

async function setupTeam(i) {
  const name = "LOAD" + i + "_" + Date.now().toString().slice(-5);
  const c = await req("POST", "/api/teams", { teamName: name, participantName: "Lead", simulationId: SIM });
  if (!c.ok) return null;
  const teamId = c.data.teamId; const P = { TEAM_LEAD: c.data.participantId };
  for (let k = 0; k < 4; k++) {
    const jr = await req("POST", `/api/teams/${teamId}/join`, { participantName: "m" + k });
    if (jr.ok) { await req("POST", `/api/teams/${teamId}/assign-role`, { participantId: jr.data.participantId, role: NONLEAD[k] }); P[NONLEAD[k]] = jr.data.participantId; }
  }
  const run = await req("POST", `/api/runs/start/${teamId}`);
  if (!run.ok) return null;
  return { teamId, runId: run.data.runId, P, name };
}

async function playTeam(team, roundRef) {
  let ok = true;
  for (let n = 1; n <= 5; n++) {
    roundRef.n = n;
    const st = await req("POST", `/api/sim2/runs/${team.runId}/rounds/${n}/start`);
    if (!st.ok) ok = false;
    await sleep(300 + Math.random() * 400); // team "works" briefly
    const sub = await req("POST", `/api/sim2/runs/${team.runId}/rounds/${n}/submission`,
      { participantId: team.P[OWNER[n]], typedAnswer: ANS[n], confidence: "HIGH" }, true);
    if (!sub.ok) { ok = false; }
    await req("GET", `/api/sim2/runs/${team.runId}/rounds/${n}/results`);
  }
  return ok;
}

async function main() {
  console.log(`── Warming backend ──`);
  for (let i = 0; i < 15; i++) { const r = await req("GET", "/api/teams/00000000-0000-0000-0000-000000000000/roles"); if (r.status) break; await sleep(4000); }

  console.log(`── Setting up ${TEAMS} teams in parallel ──`);
  const t0 = Date.now();
  const teams = (await Promise.all(Array.from({ length: TEAMS }, (_, i) => setupTeam(i)))).filter(Boolean);
  console.log(`   ${teams.length}/${TEAMS} teams created & started (${Date.now() - t0}ms)`);

  // start pollers (5 per team = ~50 clients)
  const roundRefs = teams.map(() => ({ n: 1 }));
  const pollers = [];
  teams.forEach((t, idx) => {
    for (const pid of Object.values(t.P)) pollers.push(pollClient(t.runId, pid, () => roundRefs[idx].n));
  });

  console.log(`── ${teams.length} teams playing 5 rounds + ${pollers.length} pollers ──`);
  const p0 = Date.now();
  const results = await Promise.all(teams.map((t, idx) => playTeam(t, roundRefs[idx])));
  const playMs = Date.now() - p0;
  polling = false;
  await sleep(200);

  const good = results.filter(Boolean).length;
  lat.sort((a, b) => a - b);
  const pct = (p) => lat[Math.floor(lat.length * p)] || 0;
  console.log(`\n══ LOAD RESULT ══`);
  console.log(`  teams completed all 5 rounds cleanly : ${good}/${teams.length}`);
  console.log(`  total requests                       : ${reqs}`);
  console.log(`  errors                               : ${errs} ${JSON.stringify(errKinds)}`);
  console.log(`  error rate                           : ${(errs / reqs * 100).toFixed(2)}%`);
  console.log(`  latency p50 / p95 / p99 / max (ms)   : ${pct(.5)} / ${pct(.95)} / ${pct(.99)} / ${lat[lat.length - 1]}`);
  console.log(`  playthrough wall time                : ${(playMs / 1000).toFixed(1)}s`);
  console.log(`  approx throughput                    : ${(reqs / (playMs / 1000)).toFixed(1)} req/s`);
  console.log(`\n  TEAMIDS=${teams.map(t => t.teamId).join(",")}`);
}
main().catch(e => { console.error("FATAL", e); process.exit(1); });
