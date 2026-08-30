package com.example.simulator.service;

import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.simulator.repository.ArtifactQueryRepository;

/**
 * CEO Decision Timeout Policy (script 1.7) — the per-round transactional half.
 *
 * <p>Evaluates one active round: if its deadline (round end + two-minute grace, plus any pause of
 * the clock) has passed with no CEO final decision, it applies the "No decision submitted" penalty
 * to Stakeholder Trust and Execution Quality, logs a TIMEOUT action, and advances the timeline. A
 * completed round with no final decision event is what the post-round interstitial (1.10) reads as a
 * timeout.
 */
@Service
public class Sim1RoundAdvancer {

	/** Grace after the round's nominal end before the platform gives up on a decision. */
	private static final int GRACE_SECONDS = 120;
	/** "No decision submitted" penalties, mirroring a real non-decision. */
	private static final int TRUST_DELTA = -8;
	private static final int EXECUTION_DELTA = -6;

	private final ArtifactQueryRepository repository;

	public Sim1RoundAdvancer(ArtifactQueryRepository repository) {
		this.repository = repository;
	}

	@Transactional
	public void evaluate(Map<String, Object> round) {
		UUID runId = (UUID) round.get("runId");
		int roundNumber = ((Number) round.get("roundNumber")).intValue();
		Object startedRaw = round.get("startedAt");
		Object durRaw = round.get("durationMinutes");
		if (runId == null || startedRaw == null || durRaw == null) {
			return;
		}
		LocalDateTime startedAt = startedRaw instanceof Timestamp t ? t.toLocalDateTime()
				: (LocalDateTime) startedRaw;
		int durationMinutes = ((Number) durRaw).intValue();
		Integer paused = repository.findPausedSeconds(runId, roundNumber);
		long pausedSeconds = paused == null ? 0 : paused;

		LocalDateTime deadline = startedAt
				.plusMinutes(durationMinutes)
				.plusSeconds(GRACE_SECONDS)
				.plusSeconds(pausedSeconds);

		if (LocalDateTime.now().isBefore(deadline)) {
			return; // still within time (including grace and any pause)
		}
		if (repository.countFinalDecision(runId, roundNumber) > 0) {
			return; // the CEO did submit — normal advancement already handled this
		}

		// Timed out: penalise the CEO's Trust/Execution, log it, and advance the timeline.
		UUID ceo = repository.findCeoParticipant(runId);
		if (ceo != null) {
			repository.applyTimeoutPenalty(runId, ceo, TRUST_DELTA, EXECUTION_DELTA);
		}
		repository.logTimeout(runId, roundNumber);
		repository.completeSim1Round(runId, roundNumber);
		Integer next = repository.findNextRoundNumber(runId, roundNumber);
		if (next != null) {
			repository.activateSim1Round(runId, next);
		} else {
			repository.completeRun(runId);
		}
	}
}
