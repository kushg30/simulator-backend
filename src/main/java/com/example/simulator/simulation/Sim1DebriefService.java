package com.example.simulator.simulation;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Faculty debrief for Simulator 1 (Leadership Judgment — ANP Phoenix).
 *
 * <p>Assembles the four hidden variables (Set A) the engine actually computes — Stakeholder Trust,
 * Organizational Risk, Ethical Exposure, Execution Quality — into a per-team, per-role view.
 * Students never see these numbers; the facilitator reveals them qualitatively (High / Medium /
 * Low), which is why this lives behind the faculty token and not on a student route.
 */
@Service
@Transactional(readOnly = true)
public class Sim1DebriefService {

	/** Backend construct keys, in display order. Set A — the built engine. */
	private static final List<String> CONSTRUCTS = List.of(
			"stakeholder_trust", "organizational_risk", "ethical_exposure", "execution_quality");

	private final Sim1DebriefRepository repository;

	public Sim1DebriefService(Sim1DebriefRepository repository) {
		this.repository = repository;
	}

	/**
	 * Every Simulator 1 team for a simulation, each with its role-level construct values and the
	 * team average per construct. Latest-started first.
	 */
	public Map<String, Object> debrief(UUID simulationId) {
		// run_id -> mutable accumulator
		Map<UUID, TeamAcc> byRun = new LinkedHashMap<>();

		for (Map<String, Object> row : repository.findConstructRows(simulationId)) {
			UUID runId = (UUID) row.get("runId");
			TeamAcc team = byRun.computeIfAbsent(runId,
					k -> new TeamAcc(runId, (String) row.get("teamName"), row.get("startedAt")));

			UUID participantId = (UUID) row.get("participantId");
			ParticipantAcc participant = team.participants.computeIfAbsent(participantId,
					k -> new ParticipantAcc((String) row.get("role"), (String) row.get("name")));

			String construct = (String) row.get("construct");
			Object value = row.get("value");
			if (construct != null && value != null) {
				participant.values.put(construct, ((Number) value).intValue());
			}
		}

		List<Map<String, Object>> teams = new ArrayList<>();
		for (TeamAcc team : byRun.values()) {
			Map<String, Object> t = new LinkedHashMap<>();
			t.put("runId", team.runId);
			t.put("teamName", team.teamName);
			t.put("startedAt", team.startedAt);

			// team average per construct (only over participants that recorded a value)
			Map<String, Object> teamScores = new LinkedHashMap<>();
			for (String construct : CONSTRUCTS) {
				int sum = 0;
				int n = 0;
				for (ParticipantAcc p : team.participants.values()) {
					Integer v = p.values.get(construct);
					if (v != null) {
						sum += v;
						n++;
					}
				}
				teamScores.put(construct, n == 0 ? null : Math.round((float) sum / n));
			}
			t.put("scores", teamScores);

			List<Map<String, Object>> participants = new ArrayList<>();
			for (ParticipantAcc p : team.participants.values()) {
				Map<String, Object> pm = new LinkedHashMap<>();
				pm.put("role", p.role);
				pm.put("name", p.name);
				pm.put("scores", p.values);
				participants.add(pm);
			}
			t.put("participants", participants);
			teams.add(t);
		}

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("constructs", CONSTRUCTS);
		out.put("teams", teams);
		return out;
	}

	// ----- small mutable accumulators (private to the rollup) -----

	private static final class TeamAcc {
		final UUID runId;
		final String teamName;
		final Object startedAt;
		final Map<UUID, ParticipantAcc> participants = new LinkedHashMap<>();

		TeamAcc(UUID runId, String teamName, Object startedAt) {
			this.runId = runId;
			this.teamName = teamName;
			this.startedAt = startedAt;
		}
	}

	private static final class ParticipantAcc {
		final String role;
		final String name;
		final Map<String, Integer> values = new LinkedHashMap<>();

		ParticipantAcc(String role, String name) {
			this.role = role;
			this.name = name;
		}
	}
}
