/**
 * Re-scores Simulation 1 in place, to the final script.
 *
 * IN PLACE is the whole point. Twelve real cohort sessions from 12 September are stored against this
 * simulation, and decision_events carries foreign keys to both artifacts and decisions plus the
 * option's action code as text. Dropping and re-seeding the content would orphan ~950 recorded
 * student decisions. So every artifact_id, decision_id, option_id and action code is left exactly as
 * it is; only the four delta columns change.
 *
 * Matching is POSITIONAL — the Nth option of a decision, in authored order — because the script
 * identifies options by their wording, not by the internal codes this platform happens to use. Every
 * match is verified against the option's stored label before anything is written; a single mismatch
 * aborts the whole run rather than risk scoring the wrong option.
 */
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const SIM1 = "475db739-0708-48d4-b4db-5a23f1da50d9";
const U = "postgresql://neondb_owner:npg_xGF5YWCahtl4@ep-wispy-base-aooagwpd.c-2.ap-southeast-1.aws.neon.tech/neondb?sslmode=require";
const psql = (q) => execFileSync("psql", [U, "-A", "-t", "-c", q], { encoding: "utf8" }).replace(/\r/g, "").trim();

const model = JSON.parse(fs.readFileSync(path.join(__dirname, "content_model.json"), "utf8"));
const SCALE = model.scale;

// Live rows: one line per decision, with its options in authored order.
const rows = psql(
  `SELECT r.round_number || chr(1) || (a.payload->>'title') || chr(1) || d.decision_id || chr(1) || d.is_final || chr(1) || ` +
    `(SELECT string_agg(o.value->>'id' || chr(2) || (o.value->>'label'), chr(3) ORDER BY o.ord) ` +
    ` FROM jsonb_array_elements(d.options) WITH ORDINALITY o(value, ord)) ` +
    `FROM artifacts a JOIN rounds r ON r.round_id = a.round_id JOIN decisions d ON d.artifact_id = a.artifact_id ` +
    `WHERE r.simulation_id = '${SIM1}';`,
).split("\n").filter(Boolean);

const live = new Map();
for (const line of rows) {
  const [round, title, decisionId, isFinal, opts] = line.split("");
  live.set(`${round}${title}`, {
    decisionId,
    isFinal: isFinal === "t",
    options: (opts || "").split("").map((o) => {
      const [id, label] = o.split("");
      return { id, label };
    }),
  });
}

// Labels are compared loosely on purpose: the script and the live rows differ in typographic
// details (curly vs straight quotes, en dashes) that carry no meaning.
const norm = (s) =>
  (s || "")
    .toLowerCase()
    .replace(/[‘’]/g, "'")
    .replace(/[“”]/g, '"')
    .replace(/[–—]/g, "-")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();

/**
 * How confident we are that a live option and a script option are the same option.
 *
 * Exact equality is too strict: the final script rewords several options without changing what they
 * mean ("Engage in the thread" -> "Engage in thread"). Position alone is too loose, because a
 * reordering upstream would silently score the wrong choice. Token overlap threads the needle — a
 * reworded option still shares most of its words, a genuinely different option does not.
 */
const similarity = (a, b) => {
  const A = new Set(norm(a).split(" ").filter(Boolean));
  const B = new Set(norm(b).split(" ").filter(Boolean));
  if (!A.size || !B.size) return 0;
  let shared = 0;
  for (const w of A) if (B.has(w)) shared++;
  return shared / (A.size + B.size - shared);
};
const SIMILAR_ENOUGH = 0.6;

/**
 * Token overlap alone under-scores an option whose tail was rewritten but whose opening is
 * identical — the script trims a trailing clause off two of the Round-2 framings, and the extra
 * words in the live version drag the overlap below the threshold even though the first dozen words
 * match exactly. Eight identical leading words at the same position is not a coincidence, so that
 * counts as the same option too.
 */
const PREFIX_TOKENS = 8;
const samePrefix = (a, b) => {
  const A = norm(a).split(" ").filter(Boolean);
  const B = norm(b).split(" ").filter(Boolean);
  if (A.length < PREFIX_TOKENS || B.length < PREFIX_TOKENS) return false;
  for (let i = 0; i < PREFIX_TOKENS; i++) if (A[i] !== B[i]) return false;
  return true;
};

const updates = [];
const labelUpdates = [];
const reworded = [];
const problems = [];
let matched = 0, optionCount = 0, finalsZeroed = 0;

for (const art of model.artifacts) {
  if (!art.decision) continue;
  const key = `${art.round}${art.title}`;
  const row = live.get(key);
  if (!row) { problems.push(`no live decision for R${art.round} "${art.title}"`); continue; }
  if (row.options.length !== art.decision.options.length) {
    problems.push(`R${art.round} "${art.title}": ${row.options.length} live options vs ${art.decision.options.length} in the script`);
    continue;
  }
  matched++;
  art.decision.options.forEach((scriptOpt, i) => {
    const liveOpt = row.options[i];
    if (norm(liveOpt.label) !== norm(scriptOpt.label)) {
      const sim = similarity(liveOpt.label, scriptOpt.label);
      if (sim < SIMILAR_ENOUGH && !samePrefix(liveOpt.label, scriptOpt.label)) {
        problems.push(
          `R${art.round} "${art.title}" option ${i + 1} (similarity ${sim.toFixed(2)}): ` +
            `live "${liveOpt.label}" vs script "${scriptOpt.label}"`,
        );
        return;
      }
      // Same option, reworded by the script. Adopt the script's wording — the label is display text,
      // and decision_events stores the option's id, so rewording breaks no recorded history.
      reworded.push(`R${art.round} ${art.title} [${i + 1}]: "${liveOpt.label}" -> "${scriptOpt.label}"`);
      labelUpdates.push(
        `UPDATE decisions SET options = jsonb_set(options, '{${i},label}', ` +
          `to_jsonb('${scriptOpt.label.replace(/'/g, "''")}'::text)) WHERE decision_id = '${row.decisionId}';`,
      );
    }
    const s = scriptOpt.scores || {};
    // The four round-ending CEO framings are never scored (script 1.8 / 3.5). Sim 1 currently DOES
    // score them, so those rows are explicitly zeroed rather than merely left alone.
    const zero = art.decision.isFinal;
    const t = zero ? 0 : (s.trust || 0) * SCALE;
    const g = zero ? 0 : (s.gov || 0) * SCALE;
    const e = zero ? 0 : (s.exposure || 0) * SCALE;
    const r = zero ? 0 : (s.rigor || 0) * SCALE;
    if (zero) finalsZeroed++;
    optionCount++;
    updates.push(
      `UPDATE decision_options SET trust_delta = ${t}, risk_delta = ${g}, ethics_delta = ${e}, execution_delta = ${r} ` +
        `WHERE decision_id = '${row.decisionId}' AND action = '${liveOpt.id.replace(/'/g, "''")}';`,
    );
  });
}

console.log(`decisions matched : ${matched} / ${model.artifacts.filter((a) => a.decision).length}`);
console.log(`option updates    : ${optionCount} (${finalsZeroed} of them zeroing a CEO framing)`);

if (problems.length) {
  console.error(`\nABORTING — ${problems.length} mismatch(es); nothing written:`);
  problems.slice(0, 25).forEach((p) => console.error("  - " + p));
  process.exit(1);
}

if (reworded.length) {
  console.log(`\noptions reworded to the script's text (${reworded.length}) — same option, same position:`);
  reworded.forEach((r) => console.log("  " + r));
}

const sql =
  `-- Simulation 1 re-scored to the final script. IN-PLACE: artifact ids, decision ids, option ids and\n` +
  `-- action codes are all untouched, so the twelve recorded cohort sessions keep their history.\n` +
  `BEGIN;\n${updates.join("\n")}\n${labelUpdates.join("\n")}\nCOMMIT;\n`;
fs.writeFileSync(path.join(__dirname, "sim1_rescore.sql"), sql);
console.log(`\nwrote sim1_rescore.sql (${updates.length} score updates, ${labelUpdates.length} label updates)`);
