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
        // participantId -> construct -> summed weighted delta
        Map<UUID, Map<String, Double>> deltas = new HashMap<>();
        for (Map<String, Object> row : repo.findConstructDeltas(runId)) {
            UUID pid = (UUID) row.get("participantId");
            deltas.computeIfAbsent(pid, k -> new HashMap<>())
                    .put((String) row.get("construct"), ((Number) row.get("weighted")).doubleValue());
        }

        List<Map<String, Object>> participants = new ArrayList<>();
        Map<String, List<Integer>> agg = new LinkedHashMap<>();
        CONSTRUCTS.forEach(c -> agg.put(c, new ArrayList<>()));

        for (Map<String, Object> p : repo.findRunParticipants(runId)) {
            UUID pid = (UUID) p.get("participantId");
            Map<String, Double> d = deltas.getOrDefault(pid, Map.of());
            Map<String, Object> cons = new LinkedHashMap<>();
            for (String c : CONSTRUCTS) {
                int val = clamp((int) Math.round(BASELINE + d.getOrDefault(c, 0.0)));
                cons.put(c, band(val));
                agg.get(c).add(val);
            }
            Map<String, Object> pr = new LinkedHashMap<>();
            pr.put("participantId", pid);
            pr.put("role", p.get("role"));
            pr.put("name", p.get("name"));
            pr.put("constructs", cons);
            participants.add(pr);
        }

        Map<String, Object> teamCons = new LinkedHashMap<>();
        Map<String, Integer> teamVals = new LinkedHashMap<>();
        for (String c : CONSTRUCTS) {
            List<Integer> vs = agg.get(c);
            int mean = vs.isEmpty() ? BASELINE
                    : (int) Math.round(vs.stream().mapToInt(Integer::intValue).average().orElse(BASELINE));
            teamVals.put(c, mean);
            teamCons.put(c, band(mean));
        }

        Map<String, Object> team = new LinkedHashMap<>();
        team.put("constructs", teamCons);
        team.put("dominantPattern", dominantPattern(teamVals));

        Map<String, Object> out = new LinkedHashMap<>();
        out.put("runId", runId);
        out.put("teamName", repo.findTeamName(runId));
        out.put("constructOrder", CONSTRUCTS);
        out.put("participants", participants);
        out.put("team", team);
        return out;
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
