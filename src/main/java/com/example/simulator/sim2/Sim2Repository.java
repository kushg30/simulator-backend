package com.example.simulator.sim2;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.simulator.simulation.SimulationRun;

/**
 * Data access for the Simulator-2 (Meridian Retail QBR) engine.
 *
 * <p>Deliberately separate from {@code ArtifactQueryRepository}: Sim 2 gates artifacts on
 * <em>round</em> start, whereas Sim 1 gates on <em>run</em> start. Sharing the read path would
 * mean changing Sim 1, which must stay frozen.
 */
@Repository
public interface Sim2Repository extends org.springframework.data.repository.Repository<SimulationRun, UUID> {

	// =========================================================================
	// Round lifecycle
	// =========================================================================

	@Modifying
	@Query(value = """
			INSERT INTO sim2_round_state (run_id, round_number, status, started_at, ends_at)
			SELECT :runId, :roundNumber, 'ACTIVE', now(),
			       now() + (r.duration_minutes || ' minutes')::interval
			FROM rounds r
			JOIN simulation_runs sr ON sr.simulation_id = r.simulation_id
			WHERE sr.run_id = :runId
			  AND r.round_number = :roundNumber
			ON CONFLICT (run_id, round_number) DO NOTHING
			""", nativeQuery = true)
	void startRound(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	/**
	 * Round states, with the clock shifted by any faculty pause so the countdown a student sees
	 * stops moving while the round is paused.
	 */
	@Query(value = """
			SELECT rs.round_number AS "roundNumber",
			       rs.status       AS "status",
			       rs.started_at   AS "startedAt",
			       (rs.ends_at + (COALESCE(rc.paused_seconds_total, 0)
			                    + COALESCE(EXTRACT(EPOCH FROM (now() - rc.paused_at))::int, 0)
			                     || ' seconds')::interval) AS "endsAt",
			       COALESCE(rc.paused_seconds_total, 0) AS "pausedSecondsTotal",
			       (rc.paused_at IS NOT NULL)           AS "paused",
			       -- Authoritative remaining time, computed server side. The client shows
			       -- this rather than deriving it, which avoids clock skew and stops the
			       -- countdown drifting between polls while a round is paused.
			       GREATEST(0, EXTRACT(EPOCH FROM (
			           rs.ends_at + (COALESCE(rc.paused_seconds_total, 0)
			                       + COALESCE(EXTRACT(EPOCH FROM (now() - rc.paused_at))::int, 0)
			                        || ' seconds')::interval - now()))::int) AS "remainingSeconds",
			       rs.completed_at AS "completedAt"
			FROM sim2_round_state rs
			LEFT JOIN run_round_clock rc ON rc.run_id = rs.run_id
			                            AND rc.round_number = rs.round_number
			WHERE rs.run_id = :runId
			ORDER BY rs.round_number
			""", nativeQuery = true)
	List<Map<String, Object>> findRoundStates(@Param("runId") UUID runId);

	@Query(value = """
			SELECT status FROM sim2_round_state
			WHERE run_id = :runId AND round_number = :roundNumber
			""", nativeQuery = true)
	String findRoundStatus(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	@Modifying
	@Query(value = """
			UPDATE sim2_round_state
			SET status = 'COMPLETE', completed_at = now()
			WHERE run_id = :runId AND round_number = :roundNumber
			""", nativeQuery = true)
	void completeRound(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	/**
	 * Active seconds elapsed in a round = wall-clock since round start minus any faculty-paused
	 * duration, read from the shared {@code run_round_clock} owned by the faculty control layer.
	 * A team paused by a facilitator is never penalised for time it did not have.
	 */
	@Query(value = """
			SELECT GREATEST(0,
			         EXTRACT(EPOCH FROM (now() - rs.started_at))::int
			         - COALESCE(rc.paused_seconds_total, 0)
			         - COALESCE(EXTRACT(EPOCH FROM (now() - rc.paused_at))::int, 0))
			FROM sim2_round_state rs
			LEFT JOIN run_round_clock rc ON rc.run_id = rs.run_id
			                            AND rc.round_number = rs.round_number
			WHERE rs.run_id = :runId AND rs.round_number = :roundNumber
			""", nativeQuery = true)
	Integer findActiveSecondsElapsed(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	@Query(value = """
			SELECT r.duration_minutes
			FROM rounds r
			JOIN simulation_runs sr ON sr.simulation_id = r.simulation_id
			WHERE sr.run_id = :runId AND r.round_number = :roundNumber
			""", nativeQuery = true)
	Integer findRoundDurationMinutes(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	// =========================================================================
	// Artifact visibility — offsets are relative to ROUND start, shifted by any
	// paused duration (clock-shift semantics from the faculty-control spec).
	// =========================================================================

	@Query(value = """
			SELECT
			  a.artifact_id     AS "artifactId",
			  a.artifact_type   AS "artifactType",
			  a.payload::text   AS "payload",
			  a.expected_action AS "expectedAction",
			  r.round_number    AS "roundNumber",
			  (rs.started_at + ((a.open_offset_min + COALESCE(ov.delay_minutes, 0)) || ' minutes')::interval
			                 + (pause.secs || ' seconds')::interval) AS "openAt",
			  (rs.started_at + ((a.expiry_offset_min + COALESCE(ov.delay_minutes, 0)) || ' minutes')::interval
			                 + (pause.secs || ' seconds')::interval) AS "expiresAt",
			  d.decision_id     AS "decisionId",
			  d.decision_type   AS "decisionType",
			  d.options::text   AS "decisionOptions",
			  de.action         AS "chosenAction",
			  -- OPEN only when the role of THIS participant may actually answer, so the
			  -- UI never offers buttons that would be rejected. Everyone else sees the
			  -- artifact READ_ONLY (or ACTED, once the team has answered).
			  -- NOTE: keep apostrophes out of these comments. Spring Data parses the
			  -- native query for bind parameters and treats a stray quote character as
			  -- the start of a string literal, which breaks repository creation.
			  CASE
			    WHEN de.decision_event_id IS NOT NULL THEN 'ACTED'
			    WHEN now() >= (rs.started_at
			                   + ((a.expiry_offset_min + COALESCE(ov.delay_minutes, 0)) || ' minutes')::interval
			                   + (pause.secs || ' seconds')::interval) THEN 'EXPIRED'
			    WHEN d.decision_id IS NOT NULL
			         AND (d.allowed_roles IS NULL OR jsonb_exists(d.allowed_roles, rp.role)) THEN 'OPEN'
			    ELSE 'READ_ONLY'
			  END AS "actionState"

			FROM sim2_round_state rs
			JOIN simulation_runs sr ON sr.run_id = rs.run_id
			-- Shared, simulation-agnostic clock owned by the faculty control layer.
			LEFT JOIN run_round_clock rc ON rc.run_id = rs.run_id
			                            AND rc.round_number = rs.round_number
			-- Total time to shift artifacts by: completed pauses PLUS any pause still in
			-- progress. Including the in-progress one is what freezes releases mid-pause
			-- instead of letting them all fire at once on resume.
			CROSS JOIN LATERAL (
			  SELECT COALESCE(rc.paused_seconds_total, 0)
			       + COALESCE(EXTRACT(EPOCH FROM (now() - rc.paused_at))::int, 0) AS secs
			) pause
			JOIN rounds r  ON r.simulation_id = sr.simulation_id
			              AND r.round_number  = rs.round_number
			JOIN artifacts a ON a.round_id = r.round_id
			-- Faculty delay/bypass for this run, applied per artifact.
			LEFT JOIN run_artifact_overrides ov ON ov.run_id = rs.run_id
			                                   AND ov.artifact_id = a.artifact_id
			JOIN run_participants rp ON rp.run_id = sr.run_id
			                        AND rp.run_participant_id = :participantId
			LEFT JOIN decisions d ON d.artifact_id = a.artifact_id
			-- Team-level: a Meridian twist is ONE decision for the whole team, so once
			-- any permitted member answers, everybody sees ACTED and the chosen option.
			LEFT JOIN decision_events de ON de.artifact_id = a.artifact_id
			                            AND de.run_id = sr.run_id

			WHERE rs.run_id = :runId
			  AND rs.round_number = :roundNumber
			  AND rs.status = 'ACTIVE'
			  AND now() >= (rs.started_at
			                + ((a.open_offset_min + COALESCE(ov.delay_minutes, 0)) || ' minutes')::interval
			                + (pause.secs || ' seconds')::interval)
			  -- A bypassed artifact never appears, so its decision and any conditional
			  -- trigger never fire either.
			  AND COALESCE(ov.bypassed, false) = false
			  AND (a.allowed_roles IS NULL OR jsonb_exists(a.allowed_roles, rp.role))

			ORDER BY a.open_offset_min
			""", nativeQuery = true)
	List<Sim2ArtifactView> findVisibleArtifacts(@Param("runId") UUID runId,
			@Param("participantId") UUID participantId, @Param("roundNumber") int roundNumber);

	/**
	 * Artifacts pushed into this run live by a facilitator. Kept as a separate query and merged in
	 * the service rather than UNIONed into the visibility query, which keeps both readable.
	 */
	@Query(value = """
			SELECT injection_id AS "injectionId", title AS "title", content AS "content",
			       tier AS "tier", scored AS "scored", injected_at AS "injectedAt"
			FROM run_injected_artifacts
			WHERE run_id = :runId AND round_number = :roundNumber
			ORDER BY injected_at
			""", nativeQuery = true)
	List<Map<String, Object>> findInjectedArtifacts(@Param("runId") UUID runId,
			@Param("roundNumber") int roundNumber);

	// =========================================================================
	// Participants / roles
	// =========================================================================

	@Query(value = """
			SELECT rp.role FROM run_participants rp
			WHERE rp.run_id = :runId AND rp.run_participant_id = :participantId
			""", nativeQuery = true)
	String findParticipantRole(@Param("runId") UUID runId, @Param("participantId") UUID participantId);

	@Query(value = """
			SELECT sr2.role_code
			FROM simulation_roles sr2
			JOIN simulation_runs sr ON sr.simulation_id = sr2.simulation_id
			WHERE sr.run_id = :runId AND sr2.is_lead
			""", nativeQuery = true)
	String findLeadRole(@Param("runId") UUID runId);

	// =========================================================================
	// Decisions (twists). Records into the shared ledger but deliberately does
	// NOT apply Sim-1 construct deltas.
	// =========================================================================

	/**
	 * Team-level, not per-participant: a twist is answered once for the whole team, so a second
	 * member cannot overwrite the first answer.
	 */
	@Query(value = """
			SELECT count(*) FROM decision_events
			WHERE run_id = :runId AND decision_id = :decisionId
			""", nativeQuery = true)
	int countExistingDecision(@Param("runId") UUID runId, @Param("decisionId") UUID decisionId);

	@Query(value = """
			SELECT count(*) FROM decision_options
			WHERE decision_id = :decisionId AND action = :action
			""", nativeQuery = true)
	int countValidOption(@Param("decisionId") UUID decisionId, @Param("action") String action);

	@Query(value = "SELECT d.artifact_id FROM decisions d WHERE d.decision_id = :decisionId", nativeQuery = true)
	UUID findArtifactIdByDecisionId(@Param("decisionId") UUID decisionId);

	/** JSON array of role codes permitted to answer this decision; null means anyone. */
	@Query(value = "SELECT d.allowed_roles::text FROM decisions d WHERE d.decision_id = :decisionId",
			nativeQuery = true)
	String findDecisionAllowedRoles(@Param("decisionId") UUID decisionId);

	@Modifying
	@Query(value = """
			INSERT INTO decision_events (decision_event_id, run_id, run_participant_id, artifact_id,
			                             decision_id, action, decision_type, latency_band, decided_at)
			VALUES (gen_random_uuid(), :runId, :participantId, :artifactId, :decisionId,
			        :action, 'EXPLICIT', :latencyBand, :decidedAt)
			""", nativeQuery = true)
	void insertDecisionEvent(@Param("runId") UUID runId, @Param("participantId") UUID participantId,
			@Param("artifactId") UUID artifactId, @Param("decisionId") UUID decisionId,
			@Param("action") String action, @Param("latencyBand") String latencyBand,
			@Param("decidedAt") LocalDateTime decidedAt);

	/** The twist choice for a round — drives cross-round conditionals (e.g. R1 DELETE_ROWS -> R2 flag). */
	@Query(value = """
			SELECT de.action
			FROM decision_events de
			JOIN decisions d   ON d.decision_id = de.decision_id
			JOIN artifacts a   ON a.artifact_id = d.artifact_id
			JOIN rounds r      ON r.round_id = a.round_id
			WHERE de.run_id = :runId AND r.round_number = :roundNumber
			LIMIT 1
			""", nativeQuery = true)
	String findTwistAction(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	// =========================================================================
	// Answer key (FACULTY ONLY — never expose on a student endpoint)
	// =========================================================================

	@Query(value = """
			SELECT ak.canonical_answer AS "canonicalAnswer",
			       ak.answer_type      AS "answerType",
			       ak.tolerance_abs    AS "toleranceAbs",
			       ak.tolerance_pct    AS "tolerancePct",
			       ak.question         AS "question"
			FROM sim2_answer_key ak
			JOIN simulation_runs sr ON sr.simulation_id = ak.simulation_id
			WHERE sr.run_id = :runId AND ak.round_number = :roundNumber
			""", nativeQuery = true)
	Map<String, Object> findAnswerKey(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	/** The question text alone is safe to show students. */
	@Query(value = """
			SELECT ak.question
			FROM sim2_answer_key ak
			JOIN simulation_runs sr ON sr.simulation_id = ak.simulation_id
			WHERE sr.run_id = :runId AND ak.round_number = :roundNumber
			""", nativeQuery = true)
	String findQuestion(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	// =========================================================================
	// Submissions
	// =========================================================================

	@Query(value = """
			SELECT count(*) FROM sim2_submissions
			WHERE run_id = :runId AND round_number = :roundNumber
			""", nativeQuery = true)
	int countSubmissions(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	@Modifying
	@Query(value = """
			INSERT INTO sim2_submissions (run_id, round_number, submitted_by, file_path,
			                              original_filename, typed_answer, confidence,
			                              active_seconds_used, is_correct, score_detail)
			VALUES (:runId, :roundNumber, :submittedBy, :filePath, :originalFilename,
			        :typedAnswer, :confidence, :activeSeconds, :isCorrect, CAST(:scoreDetail AS jsonb))
			""", nativeQuery = true)
	void insertSubmission(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber,
			@Param("submittedBy") UUID submittedBy, @Param("filePath") String filePath,
			@Param("originalFilename") String originalFilename, @Param("typedAnswer") String typedAnswer,
			@Param("confidence") String confidence, @Param("activeSeconds") Integer activeSeconds,
			@Param("isCorrect") Boolean isCorrect, @Param("scoreDetail") String scoreDetail);

	@Query(value = """
			SELECT round_number AS "roundNumber", typed_answer AS "typedAnswer",
			       confidence AS "confidence", is_correct AS "isCorrect",
			       original_filename AS "originalFilename", submitted_at AS "submittedAt",
			       active_seconds_used AS "activeSecondsUsed"
			FROM sim2_submissions
			WHERE run_id = :runId AND round_number = :roundNumber
			""", nativeQuery = true)
	Map<String, Object> findSubmission(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	// =========================================================================
	// Construct scores
	// =========================================================================

	@Modifying
	@Query(value = """
			INSERT INTO sim2_construct_scores (run_id, round_number, construct_name, value, status, detail)
			VALUES (:runId, :roundNumber, :constructName, :value, :status, :detail)
			ON CONFLICT (run_id, round_number, construct_name) DO UPDATE
			SET value = EXCLUDED.value, status = EXCLUDED.status,
			    detail = EXCLUDED.detail, calculated_at = now()
			""", nativeQuery = true)
	void upsertConstructScore(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber,
			@Param("constructName") String constructName, @Param("value") Integer value,
			@Param("status") String status, @Param("detail") String detail);

	@Query(value = """
			SELECT construct_name AS "construct", value AS "value",
			       status AS "status", detail AS "detail"
			FROM sim2_construct_scores
			WHERE run_id = :runId AND round_number = :roundNumber
			ORDER BY construct_name
			""", nativeQuery = true)
	List<Map<String, Object>> findConstructScores(@Param("runId") UUID runId,
			@Param("roundNumber") int roundNumber);

	/**
	 * Rollup across rounds. A bypassed round is EXCLUDED from the average rather than counted as
	 * zero, because it was not attempted rather than failed. Checks both the round status and the
	 * platform bypass table, so a round bypassed by a facilitator is dropped either way.
	 */
	@Query(value = """
			SELECT cs.construct_name AS "construct", ROUND(AVG(cs.value))::int AS "value"
			FROM sim2_construct_scores cs
			JOIN sim2_round_state rs ON rs.run_id = cs.run_id AND rs.round_number = cs.round_number
			WHERE cs.run_id = :runId
			  AND cs.status = 'SCORED'
			  AND rs.status <> 'BYPASSED'
			  AND NOT EXISTS (SELECT 1 FROM run_round_bypass b
			                   WHERE b.run_id = cs.run_id AND b.round_number = cs.round_number)
			GROUP BY cs.construct_name
			ORDER BY cs.construct_name
			""", nativeQuery = true)
	List<Map<String, Object>> findConstructRollup(@Param("runId") UUID runId);
}
