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

	// ------------------------------------------------------------------ console

	@Transactional(readOnly = true)
	public List<Map<String, Object>> sessionOverview() {
		return repository.findSessionOverview();
	}

	@Transactional(readOnly = true)
	public List<Map<String, Object>> roundArtifacts(UUID runId, int roundNumber) {
		return repository.findRoundArtifacts(runId, roundNumber);
	}

	// ------------------------------------------------------------------ delay

	/**
	 * Delays an artifact, and everything scheduled after it in that round, by the same number of
	 * minutes. Typical use is a team visibly behind before a twist would land: delay the twist a
	 * few minutes rather than pausing the whole round.
	 */
	public Map<String, Object> delay(UUID runId, int roundNumber, UUID artifactId, int minutes,
			String note, String actor) {
		if (minutes <= 0) {
			throw new IllegalArgumentException("Delay must be a positive number of minutes");
		}
		repository.delayFrom(runId, roundNumber, artifactId, minutes);
		log(runId, roundNumber, "DELAY", "TEAM", artifactId, minutes, null, note, actor);
		return Map.of("runId", runId, "roundNumber", roundNumber, "artifactId", artifactId,
				"delayedByMinutes", minutes);
	}

	// ------------------------------------------------------------------ bypass

	/** Skips one artifact: its micro-decision and any conditional trigger simply never appear. */
	public Map<String, Object> bypassArtifact(UUID runId, int roundNumber, UUID artifactId,
			String note, String actor) {
		repository.bypassArtifact(runId, artifactId);
		log(runId, roundNumber, "BYPASS", "TEAM", artifactId, null, null, note, actor);
		return Map.of("runId", runId, "artifactId", artifactId, "bypassed", true);
	}

	/**
	 * Skips a whole round. The round is excluded from the construct rollup rather than scored zero
	 * — a bypassed round is "not attempted", not "failed".
	 */
	public Map<String, Object> bypassRound(UUID runId, int roundNumber, String reason, String actor) {
		repository.bypassRound(runId, roundNumber, reason);
		repository.markRoundBypassed(runId, roundNumber);
		log(runId, roundNumber, "BYPASS", "TEAM", null, null, null, reason, actor);
		return Map.of("runId", runId, "roundNumber", roundNumber, "bypassed", true,
				"note", "Excluded from the construct rollup, not scored as zero");
	}

	// ------------------------------------------------------- restart a round

	/**
	 * Undo an accidental submission: re-open the most recently submitted round so the team can
	 * submit it again. Removes that round's submission and construct scores (and any finalised
	 * run-level scores). The round clock is deliberately left running.
	 */
	public Map<String, Object> restartLastRound(UUID runId, String note, String actor) {
		Integer round = repository.findLastCompleteSim2Round(runId);
		if (round == null) {
			throw new IllegalStateException("This team has not submitted a round yet");
		}
		repository.deleteSim2Submission(runId, round);
		repository.deleteSim2RoundScores(runId, round);
		repository.reopenSim2Round(runId, round);
		repository.reactivateRun(runId); // recover a run that was terminated by mistake
		log(runId, round, "RESTART", "TEAM", null, null, null, note, actor);
		return Map.of("runId", runId, "roundNumber", round, "restarted", true,
				"note", "Round " + round + " re-opened for submission; the clock kept running");
	}

	// ------------------------------------------------------------- terminate

	/**
	 * Ends a run for good. Its artifacts stop firing and it drops off the console. Irreversible, so
	 * the UI guards it behind a typed confirmation; the action is logged for the record.
	 */
	public Map<String, Object> terminate(UUID runId, String note, String actor) {
		repository.terminateRun(runId);
		log(runId, null, "TERMINATE", "TEAM", null, null, null, note, actor);
		return Map.of("runId", runId, "terminated", true);
	}

	// --------------------------------------------------------------- injection

	@Transactional(readOnly = true)
	public List<Map<String, Object>> catalogue(UUID simulationId) {
		return repository.findCatalogue(simulationId);
	}

	/**
	 * Pushes an artifact into a live run.
	 *
	 * <p>Two tiers, deliberately different in what they may affect. A CATALOGUE entry is
	 * pre-vetted and already carries a canonical answer, so it may be scored. An ON_THE_FLY
	 * artifact is context-only: the platform refuses to accept it as a graded round-ender unless
	 * the facilitator supplies a canonical answer at the moment of injection, because grading a
	 * team against an answer nobody defined in advance is worse than not grading that round.
	 */
	public Map<String, Object> inject(UUID runId, int roundNumber, UUID catalogueId, String title,
			String content, boolean scored, String canonicalAnswer, String actor) {

		String tier;
		String finalTitle = title;
		String finalContent = content;
		String finalAnswer = canonicalAnswer;

		if (catalogueId != null) {
			Map<String, Object> entry = repository.findCatalogueEntry(catalogueId);
			if (entry == null) {
				throw new IllegalStateException("Unknown catalogue artifact");
			}
			tier = "CATALOGUE";
			finalTitle = String.valueOf(entry.get("title"));
			finalContent = String.valueOf(entry.get("content"));
			if (finalAnswer == null) {
				finalAnswer = (String) entry.get("canonicalAnswer");
			}
			// A catalogue CONTEXT entry carries no answer and still cannot be scored.
			if (scored && finalAnswer == null) {
				throw new IllegalStateException(
						"This catalogue artifact is context-only and cannot be scored");
			}
		} else {
			tier = "ON_THE_FLY";
			if (finalTitle == null || finalTitle.isBlank() || finalContent == null || finalContent.isBlank()) {
				throw new IllegalStateException("An on-the-fly artifact needs a title and content");
			}
			if (scored && (finalAnswer == null || finalAnswer.isBlank())) {
				throw new IllegalStateException(
						"An on-the-fly artifact cannot be scored without a canonical answer supplied "
								+ "at the moment of injection");
			}
		}

		repository.injectArtifact(runId, roundNumber, catalogueId, finalTitle, finalContent, tier,
				scored, finalAnswer);

		// Ad hoc overrides are flagged distinctly in the log so they can be reviewed later.
		String note = (tier.equals("ON_THE_FLY") && scored)
				? "AD HOC SCORED OVERRIDE - answer supplied at injection, not from the answer key"
				: finalTitle;
		log(runId, roundNumber, "INJECT", "TEAM", null, null,
				"{\"tier\":\"" + tier + "\",\"scored\":" + scored + "}", note, actor);

		return Map.of("runId", runId, "roundNumber", roundNumber, "tier", tier, "scored", scored,
				"title", finalTitle);
	}

	// ------------------------------------------------------------------ internal

	private void log(UUID runId, Integer roundNumber, String actionType, String scope,
			UUID targetArtifact, Integer delayMinutes, String injectedContent, String note, String actor) {
		repository.logAction(repository.findSimulationId(runId), runId, repository.findTeamId(runId),
				roundNumber, actionType, scope, targetArtifact, delayMinutes, injectedContent, note,
				actor == null ? "facilitator" : actor);
	}
}
