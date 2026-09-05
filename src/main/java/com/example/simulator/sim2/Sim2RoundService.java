package com.example.simulator.sim2;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

/** Round lifecycle, artifact visibility and twist decisions for Simulator 2. */
@Service
@Transactional
public class Sim2RoundService {

	private final Sim2Repository repository;
	private final ObjectMapper objectMapper;

	public Sim2RoundService(Sim2Repository repository, ObjectMapper objectMapper) {
		this.repository = repository;
		this.objectMapper = objectMapper;
	}

	/**
	 * Starts a round's clock. Idempotent: re-starting an already-started round is a no-op.
	 *
	 * <p>Teams may not skip ahead: a NEW round only starts once the previous round's timer has fully
	 * elapsed. Submitting early records the answer but does not unlock the next round — the round is
	 * time-boxed. (Re-entering an already-started round is always allowed.)
	 */
	public Map<String, Object> startRound(UUID runId, int roundNumber) {
		String existing = repository.findRoundStatus(runId, roundNumber);
		if (existing == null && roundNumber > 1) {
			Integer prevRemaining = repository.findRoundRemainingSeconds(runId, roundNumber - 1);
			if (prevRemaining != null && prevRemaining > 0) {
				throw new IllegalStateException(
						"Round " + (roundNumber - 1) + " is still running — the next round starts when its timer ends");
			}
		}
		repository.startRound(runId, roundNumber);
		String status = repository.findRoundStatus(runId, roundNumber);
		if (status == null) {
			throw new IllegalStateException("Round " + roundNumber + " does not exist for this run");
		}
		return Map.of("runId", runId, "roundNumber", roundNumber, "status", status);
	}

	@Transactional(readOnly = true)
	public List<Map<String, Object>> getRoundStates(UUID runId) {
		return repository.findRoundStates(runId);
	}

	@Transactional(readOnly = true)
	public List<Map<String, Object>> getVisibleArtifacts(UUID runId, UUID participantId, int roundNumber) {

		List<Map<String, Object>> out = new ArrayList<>();
		for (Sim2ArtifactView v : repository.findVisibleArtifacts(runId, participantId, roundNumber)) {
			Map<String, Object> m = new LinkedHashMap<>();
			m.put("artifactId", v.getArtifactId());
			m.put("artifactType", v.getArtifactType());
			m.put("payload", v.getPayload());
			m.put("expectedAction", Boolean.TRUE.equals(v.getExpectedAction()));
			m.put("roundNumber", v.getRoundNumber());
			m.put("openAt", v.getOpenAt());
			m.put("expiresAt", v.getExpiresAt());
			m.put("decisionId", v.getDecisionId());
			m.put("decisionType", v.getDecisionType());
			m.put("decisionOptions", v.getDecisionOptions());
			m.put("chosenAction", v.getChosenAction());
			m.put("actionState", v.getActionState());
			out.add(m);
		}

		// Artifacts injected live by a facilitator. They carry no decision and are always
		// read-only to students; a scored injection is graded through the round submission.
		for (Map<String, Object> inj : repository.findInjectedArtifacts(runId, roundNumber)) {
			Map<String, Object> m = new LinkedHashMap<>();
			m.put("artifactId", inj.get("injectionId"));
			m.put("artifactType", "INJECTED");
			m.put("payload", "{\"tab\":\"inbox\",\"from\":\"Facilitator\",\"title\":"
					+ jsonString(String.valueOf(inj.get("title"))) + ",\"body\":"
					+ jsonString(String.valueOf(inj.get("content"))) + "}");
			m.put("expectedAction", false);
			m.put("roundNumber", roundNumber);
			m.put("openAt", inj.get("injectedAt"));
			m.put("expiresAt", null);
			m.put("decisionId", null);
			m.put("decisionType", null);
			m.put("decisionOptions", null);
			m.put("chosenAction", null);
			m.put("actionState", "READ_ONLY");
			out.add(m);
		}
		return out;
	}

	/** Minimal JSON string escaping for the synthesised injected-artifact payload. */
	private String jsonString(String s) {
		if (s == null) {
			return "\"\"";
		}
		return "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"")
				.replace("\n", "\\n").replace("\r", "") + "\"";
	}

	/**
	 * Records a twist decision.
	 *
	 * <p>Writes to the shared {@code decision_events} ledger but deliberately does NOT call
	 * {@code applyConstructDeltas} — those trust/risk/ethics/execution deltas belong to
	 * Simulation 1's engine and have no meaning here.
	 */
	public void recordDecision(UUID runId, UUID participantId, UUID decisionId, String action) {

		String role = repository.findParticipantRole(runId, participantId);
		if (role == null) {
			throw new IllegalStateException("Participant is not part of this run");
		}
		Integer round = repository.findRoundNumberByDecision(decisionId);
		if (round == null) {
			throw new IllegalStateException("Decision is not linked to a round");
		}
		// A paused round is frozen for everyone: no artifact fires and no decision lands.
		if (Boolean.TRUE.equals(repository.isRoundPaused(runId, round))) {
			throw new IllegalStateException("The round is paused; please wait for the facilitator to resume");
		}
		if (!isRoleAllowed(decisionId, role)) {
			throw new IllegalStateException("Role " + role + " is not permitted to answer this decision");
		}
		if (repository.countExistingDecision(runId, decisionId) > 0) {
			throw new IllegalStateException("Your team has already answered this decision");
		}
		if (repository.countValidOption(decisionId, action) == 0) {
			throw new IllegalStateException("Invalid action for this decision");
		}

		UUID artifactId = repository.findArtifactIdByDecisionId(decisionId);
		if (artifactId == null) {
			throw new IllegalStateException("Decision is not linked to an artifact");
		}

		repository.insertDecisionEvent(runId, participantId, artifactId, decisionId, action,
				latencyBand(runId, round), LocalDateTime.now());
	}

	/**
	 * Whether a role may answer a decision. A null/absent {@code allowed_roles}, or the literal
	 * "ALL", means anyone on the team may answer. Mirrors the check Simulation 1 performs in
	 * {@code DecisionWriteService} — without it, any role could answer any twist.
	 */
	private boolean isRoleAllowed(UUID decisionId, String role) {
		String json = repository.findDecisionAllowedRoles(decisionId);
		if (json == null || json.isBlank()) {
			return true;
		}
		try {
			List<String> allowed = objectMapper.readValue(json, new TypeReference<List<String>>() {
			});
			return allowed.isEmpty() || allowed.contains("ALL") || allowed.contains(role);
		} catch (Exception e) {
			throw new IllegalStateException("Invalid allowed_roles format on decision " + decisionId);
		}
	}

	/**
	 * EARLY / MODERATE / DELAYED relative to how much of the round's active time has elapsed.
	 * Matches Sim 1's thirds convention so the two ledgers stay comparable.
	 */
	private String latencyBand(UUID runId, int roundNumber) {
		Integer elapsed = repository.findActiveSecondsElapsed(runId, roundNumber);
		Integer durationMin = repository.findRoundDurationMinutes(runId, roundNumber);
		if (elapsed == null || durationMin == null || durationMin <= 0) {
			return "MODERATE";
		}
		double ratio = elapsed / (double) (durationMin * 60);
		return ratio <= 0.33 ? "EARLY" : ratio <= 0.66 ? "MODERATE" : "DELAYED";
	}
}
