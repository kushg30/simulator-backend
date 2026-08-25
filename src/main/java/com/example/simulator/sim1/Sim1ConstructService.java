package com.example.simulator.sim1;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Set-B scoring for Simulator 1 (Leadership Judgment), Phase 1.
 *
 * <p>Computes the five canonical constructs — Early Signal Legitimization, Silence Accumulation, Framing
 * Commitment, Authority Centralization, Option Space Contraction — per participant and for the team, from
 * the recorded decisions and the per-option mapping, with the spec's time-weighting. Values are 0-100
 * internally and surfaced only as Low / Medium / High. (Interaction and threshold effects are Phase 2.)
 */
@Service
@Transactional(readOnly = true)
public class Sim1ConstructService {

    private final Sim1ConstructRepository repo;

    public Sim1ConstructService(Sim1ConstructRepository repo) {
        this.repo = repo;
    }

    static final String ESL = "EARLY_SIGNAL_LEGITIMIZATION";
    static final String SIL = "SILENCE_ACCUMULATION";
    static final String FRM = "FRAMING_COMMITMENT";
    static final String AUTH = "AUTHORITY_CENTRALIZATION";
    static final String OSC = "OPTION_SPACE_CONTRACTION";
    static final List<String> CONSTRUCTS = List.of(ESL, SIL, FRM, AUTH, OSC);

    // Constructs start neutral and are moved by decisions; ESL higher is good, the rest higher is adverse.
    private static final int BASELINE = 50;

    public Map<String, Object> constructs(UUID runId) {
        // participantId -> construct -> summed weighted delta (all rounds); plus Round-1-only silence.
        Map<UUID, Map<String, Double>> deltas = new HashMap<>();
        Map<UUID, Double> r1Silence = new HashMap<>();
        for (Map<String, Object> row : repo.findConstructDeltas(runId)) {
            UUID pid = (UUID) row.get("participantId");
            String c = (String) row.get("construct");
            double w = ((Number) row.get("weighted")).doubleValue();
            deltas.computeIfAbsent(pid, k -> new HashMap<>()).merge(c, w, Double::sum);
            if (SIL.equals(c) && ((Number) row.get("round")).intValue() == 1) {
                r1Silence.merge(pid, w, Double::sum);
            }
        }

        List<Map<String, Object>> participants = new ArrayList<>();
        Map<String, List<Integer>> agg = new LinkedHashMap<>();
        CONSTRUCTS.forEach(c -> agg.put(c, new ArrayList<>()));
        List<Integer> r1SilVals = new ArrayList<>();

        for (Map<String, Object> p : repo.findRunParticipants(runId)) {
            UUID pid = (UUID) p.get("participantId");
            Map<String, Double> d = deltas.getOrDefault(pid, Map.of());
            Map<String, Object> cons = new LinkedHashMap<>();
            for (String c : CONSTRUCTS) {
                int val = clamp((int) Math.round(BASELINE + d.getOrDefault(c, 0.0)));
                cons.put(c, band(val));
                agg.get(c).add(val);
            }
            r1SilVals.add(clamp((int) Math.round(BASELINE + r1Silence.getOrDefault(pid, 0.0))));
            Map<String, Object> pr = new LinkedHashMap<>();
            pr.put("participantId", pid);
            pr.put("role", p.get("role"));
            pr.put("name", p.get("name"));
            pr.put("constructs", cons);
            participants.add(pr);
        }

        // Team base = mean of participants per construct.
        Map<String, Integer> teamVals = new LinkedHashMap<>();
        for (String c : CONSTRUCTS) {
            teamVals.put(c, mean(agg.get(c)));
        }
        int round1Silence = mean(r1SilVals);

        // ── Phase 2: interaction + threshold on Option Space Contraction ──────────
        // Silence and framing compound to accelerate option-space loss (spec's interaction formula,
        // normalized): extra = (Sil*0.4 + Frm*0.3 + Sil*Frm*0.5) over 0-1, scaled to ~0-30 points.
        double sil01 = teamVals.get(SIL) / 100.0;
        double frm01 = teamVals.get(FRM) / 100.0;
        int interaction = (int) Math.round((sil01 * 0.4 + frm01 * 0.3 + sil01 * frm01 * 0.5) * 25);
        int oscBase = teamVals.get(OSC);
        int oscAdjusted = clamp(oscBase + interaction);

        // Threshold: Round-1 silence at/above 65 forecloses Round-2 escalation — options were already
        // effectively closed entering Round 2, so option-space contraction takes a further step.
        boolean escalationForeclosed = round1Silence >= 65;
        if (escalationForeclosed) {
            oscAdjusted = clamp(oscAdjusted + 15);
        }
        teamVals.put(OSC, oscAdjusted);

        Map<String, Object> teamCons = new LinkedHashMap<>();
        for (String c : CONSTRUCTS) {
            teamCons.put(c, band(teamVals.get(c)));
        }

        List<String> insights = new ArrayList<>();
        if (escalationForeclosed) {
            insights.add("Round-1 silence foreclosed escalation — options were effectively closed entering "
                    + "Round 2 (Silence R1 = " + round1Silence + ").");
        }
        if (interaction >= 10) {
            insights.add("Silence and framing compounded to accelerate option-space contraction (+"
                    + interaction + ").");
        }
        if (teamVals.get(ESL) >= 70) {
            insights.add("Weak signals were legitimized early and the team kept its options open.");
        }

        Map<String, Object> effects = new LinkedHashMap<>();
        effects.put("optionSpaceBase", oscBase);
        effects.put("optionSpaceInteraction", interaction);
        effects.put("round1Silence", round1Silence);
        effects.put("escalationForeclosed", escalationForeclosed);
        effects.put("optionSpaceAdjusted", oscAdjusted);

        Map<String, Object> team = new LinkedHashMap<>();
        team.put("constructs", teamCons);
        team.put("dominantPattern", dominantPattern(teamVals));
        team.put("effects", effects);
        team.put("insights", insights);

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("runId", runId);
        out.put("teamName", repo.findTeamName(runId));
        out.put("constructOrder", CONSTRUCTS);
        out.put("participants", participants);
        out.put("team", team);
        return out;
    }

    private int mean(List<Integer> vs) {
        return vs.isEmpty() ? BASELINE
                : (int) Math.round(vs.stream().mapToInt(Integer::intValue).average().orElse(BASELINE));
    }

    /** Every played team for a simulation, plus auto-generated class-level insight statements. */
    public Map<String, Object> cohort(UUID simulationId) {
        List<Map<String, Object>> teams = new ArrayList<>();
        for (Map<String, Object> run : repo.findRunsForSimulation(simulationId)) {
            Map<String, Object> team = constructs((UUID) run.get("runId"));
            team.put("startedAt", run.get("startedAt"));
            teams.add(team);
        }
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("constructOrder", CONSTRUCTS);
        out.put("teams", teams);
        out.put("classInsights", classInsights(teams));
        return out;
    }

    @SuppressWarnings("unchecked")
    private List<String> classInsights(List<Map<String, Object>> teams) {
        List<String> out = new ArrayList<>();
        int n = teams.size();
        if (n == 0) {
            return out;
        }
        int normalized = 0, narrowed = 0, foreclosed = 0, legitimized = 0;
        Map<String, Integer> patterns = new LinkedHashMap<>();
        for (Map<String, Object> t : teams) {
            Map<String, Object> team = (Map<String, Object>) t.get("team");
            Map<String, Object> cons = (Map<String, Object>) team.get("constructs");
            String eslBand = (String) ((Map<String, Object>) cons.get(ESL)).get("band");
            String oscBand = (String) ((Map<String, Object>) cons.get(OSC)).get("band");
            if ("Low".equals(eslBand)) normalized++;
            if ("High".equals(eslBand)) legitimized++;
            if ("High".equals(oscBand)) narrowed++;
            Map<String, Object> eff = (Map<String, Object>) team.get("effects");
            if (Boolean.TRUE.equals(eff.get("escalationForeclosed"))) {
                foreclosed++;
            }
            patterns.merge((String) team.get("dominantPattern"), 1, Integer::sum);
        }
        out.add(pct(normalized, n) + "% of teams normalized weak signals before escalation became "
                + "legitimate (low Early Signal Legitimization).");
        out.add(pct(narrowed, n) + "% of teams narrowed their option space to High by the final round.");
        if (legitimized > 0) {
            out.add(pct(legitimized, n) + "% of teams legitimized the signal early and kept options open.");
        }
        if (foreclosed > 0) {
            out.add(pct(foreclosed, n) + "% crossed the Round-1 silence threshold that forecloses escalation.");
        }
        patterns.entrySet().stream().max(Map.Entry.comparingByValue()).ifPresent(e ->
                out.add("The most common leadership pattern was \"" + e.getKey() + "\" (" + e.getValue()
                        + " of " + n + " teams)."));
        return out;
    }

    private int pct(int x, int n) {
        return (int) Math.round(100.0 * x / n);
    }

    private int clamp(int v) {
        return Math.max(0, Math.min(100, v));
    }

    /** Numeric value plus its Low/Medium/High band — students only ever see the band. */
    private Map<String, Object> band(int v) {
        String b = v >= 70 ? "High" : v >= 40 ? "Medium" : "Low";
        Map<String, Object> m = new LinkedHashMap<>();
        m.put("value", v);
        m.put("band", b);
        return m;
    }

    /**
     * Dominant pattern from the two most-elevated adverse constructs (Phase-1 heuristic; the spec's fuller
     * pattern library lands with the dashboards in Phase 3).
     */
    private String dominantPattern(Map<String, Integer> t) {
        Map<String, Integer> adverse = new LinkedHashMap<>();
        adverse.put(SIL, t.get(SIL));
        adverse.put(FRM, t.get(FRM));
        adverse.put(AUTH, t.get(AUTH));
        adverse.put(OSC, t.get(OSC));

        if (t.get(ESL) >= 70 && adverse.values().stream().allMatch(v -> v < 50)) {
            return "Signals legitimized, options preserved";
        }
        List<String> top = adverse.entrySet().stream()
                .sorted((a, b) -> b.getValue() - a.getValue())
                .limit(2).map(Map.Entry::getKey).toList();
        Set<String> s = Set.copyOf(top);
        if (s.equals(Set.of(SIL, OSC))) return "Early normalization under growth pressure";
        if (s.equals(Set.of(FRM, AUTH))) return "Authority-driven framing";
        if (s.equals(Set.of(AUTH, SIL))) return "Judgment collapsed upward";
        if (s.equals(Set.of(FRM, OSC))) return "Framing hardened, options narrowed";
        if (s.equals(Set.of(SIL, FRM))) return "Silent normalization";
        if (s.equals(Set.of(AUTH, OSC))) return "Centralized, narrowing judgment";
        return "Mixed pattern";
    }
}
