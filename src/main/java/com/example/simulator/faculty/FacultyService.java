package com.example.simulator.faculty;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Platform-wide faculty controls.
 *
 * <p>Every action is applied AND logged: the action log is what makes the active-time maths and
 * the bypass/rollup exclusion defensible if a team later disputes a score.
 */
@Service
@Transactional
public class FacultyService {

	private final FacultyRepository repository;

	public FacultyService(FacultyRepository repository) {
		this.repository = repository;
	}

	// ------------------------------------------------------------------ pause

	/**
	 * Freezes a round clock. While paused, no artifact fires: the engines add both the accumulated
	 * pause and the in-progress one to every artifact offset, so the whole schedule slides rather
	 * than catching up in a burst on resume.
	 */
	public Map<String, Object> pause(UUID runId, int roundNumber, String note, String actor) {
		repository.pause(runId, roundNumber);
		log(runId, roundNumber, "PAUSE", "TEAM", null, null, null, note, actor);
		return status(runId, roundNumber);
	}

	/** Ends the pause and folds its duration into the accumulated total. */
	public Map<String, Object> resume(UUID runId, int roundNumber, String note, String actor) {
		repository.resume(runId, roundNumber);
		log(runId, roundNumber, "RESUME", "TEAM", null, null, null, note, actor);
		return status(runId, roundNumber);
	}

	/** Same action across every active round of a simulation (whole-class outage, fire drill). */
	public List<Map<String, Object>> pauseAll(UUID simulationId, boolean pause, String note, String actor) {
		List<Map<String, Object>> affected = new ArrayList<>();
		for (Map<String, Object> round : repository.findActiveRounds(simulationId)) {
			UUID runId = (UUID) round.get("runId");
			int roundNumber = ((Number) round.get("roundNumber")).intValue();
			if (pause) {
				repository.pause(runId, roundNumber);
			} else {
				repository.resume(runId, roundNumber);
			}
			log(runId, roundNumber, pause ? "PAUSE" : "RESUME", "ALL", null, null, null, note, actor);

			Map<String, Object> entry = new LinkedHashMap<>(status(runId, roundNumber));
			entry.put("teamName", round.get("teamName"));
			affected.add(entry);
		}
		return affected;
	}

	@Transactional(readOnly = true)
	public Map<String, Object> status(UUID runId, int roundNumber) {
		Map<String, Object> clock = repository.findClock(runId, roundNumber);
		Map<String, Object> out = new LinkedHashMap<>();
		out.put("runId", runId);
		out.put("roundNumber", roundNumber);
		out.put("paused", clock != null && Boolean.TRUE.equals(clock.get("paused")));
		out.put("pausedSecondsTotal", clock == null ? 0 : clock.get("pausedSecondsTotal"));
		out.put("pausedAt", clock == null ? null : clock.get("pausedAt"));
		return out;
	}

	@Transactional(readOnly = true)
	public List<Map<String, Object>> actionLog(UUID runId) {
		return repository.findActions(runId);
	}

	// ------------------------------------------------------------------ internal

	private void log(UUID runId, Integer roundNumber, String actionType, String scope,
			UUID targetArtifact, Integer delayMinutes, String injectedContent, String note, String actor) {
		repository.logAction(repository.findSimulationId(runId), runId, repository.findTeamId(runId),
				roundNumber, actionType, scope, targetArtifact, delayMinutes, injectedContent, note,
				actor == null ? "facilitator" : actor);
	}
}
