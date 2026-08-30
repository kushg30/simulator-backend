package com.example.simulator.repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import com.example.simulator.projection.DecisionMetaView;
import com.example.simulator.projection.VisibleArtifactView;
import com.example.simulator.simulation.SimulationRun;

@Repository
public interface ArtifactQueryRepository extends org.springframework.data.repository.Repository<SimulationRun, UUID> {

	// =========================
	// READ: visible artifacts
	// =========================
	// Offsets are relative to the run start, shifted by any faculty pause
	// (run_round_clock, round 1) and per-artifact delay (run_artifact_overrides),
	// mirroring the Simulator 2 read path so the shared faculty controls actually
	// take effect on Simulation 1 too. Bypassed artifacts and terminated runs
	// drop out entirely.
	@Query(value = """
			SELECT
			  a.artifact_id AS artifactId,
			  a.artifact_type AS artifactType,
			  a.payload::text AS payload,
			  a.expected_action AS expectedAction,
			  r.round_number AS roundNumber,
			  (rs.started_at + ((a.open_offset_min + COALESCE(ov.delay_minutes, 0)) || ' minutes')::interval
			                 + (pause.secs || ' seconds')::interval) AS openAt,
			  (rs.started_at + ((a.expiry_offset_min + COALESCE(ov.delay_minutes, 0)) || ' minutes')::interval
			                 + (pause.secs || ' seconds')::interval) AS expiresAt,
			  d.decision_id AS decisionId,
			  d.decision_type AS decisionType,
			  d.options::text AS decisionOptions,
			  de.action AS chosenAction,
			  d.allowed_roles::text AS allowedRoles,

			  CASE
			    WHEN de.decision_event_id IS NOT NULL THEN 'ACTED'
			    WHEN now() >= (rs.started_at
			                   + ((a.expiry_offset_min + COALESCE(ov.delay_minutes, 0)) || ' minutes')::interval
			                   + (pause.secs || ' seconds')::interval) THEN 'EXPIRED'
			    WHEN d.decision_id IS NOT NULL THEN 'OPEN'
			    ELSE 'READ_ONLY'
			  END AS actionState

			FROM simulation_runs sr

			JOIN run_participants rp
			  ON rp.run_id = sr.run_id
			 AND rp.run_participant_id = :participantId

			-- The run's currently-active round; offsets are relative to THIS round's
			-- start, so each round has its own T+0 timeline (multi-round support).
			JOIN sim1_round_state rs ON rs.run_id = sr.run_id AND rs.status = 'ACTIVE'

			LEFT JOIN run_round_clock rc ON rc.run_id = sr.run_id AND rc.round_number = rs.round_number
			CROSS JOIN LATERAL (
			  SELECT COALESCE(rc.paused_seconds_total, 0)
			       + COALESCE(EXTRACT(EPOCH FROM (now() - rc.paused_at))::int, 0)
			       -- a News interrupt (1.2) slides the whole schedule for up to its pause_seconds,
			       -- ramping while the modal is live and locking in once it elapses.
			       + COALESCE((SELECT SUM(LEAST(EXTRACT(EPOCH FROM (now() - n.created_at)), n.pause_seconds))::int
			                   FROM sim1_news n
			                   WHERE n.run_id = sr.run_id AND n.round_number = rs.round_number), 0) AS secs
			) pause

			JOIN rounds r ON r.simulation_id = sr.simulation_id AND r.round_number = rs.round_number
			JOIN artifacts a ON a.round_id = r.round_id

			LEFT JOIN run_artifact_overrides ov ON ov.run_id = sr.run_id
			                                   AND ov.artifact_id = a.artifact_id

			LEFT JOIN decisions d ON d.artifact_id = a.artifact_id

			LEFT JOIN decision_events de
			  ON de.artifact_id = a.artifact_id
			 AND de.run_id = sr.run_id
			 AND de.run_participant_id = :participantId

			WHERE sr.run_id = :runId
			AND sr.status <> 'TERMINATED'
			AND COALESCE(ov.bypassed, false) = false

			AND NOT EXISTS (
				    SELECT 1
				    FROM artifact_conditions ac
				    WHERE ac.artifact_id = a.artifact_id
				      AND NOT EXISTS (
				          SELECT 1
				          FROM decision_events de_cond
				          WHERE de_cond.decision_id = ac.depends_on_decision_id
				            AND de_cond.run_id = sr.run_id
				            AND de_cond.run_participant_id = :participantId
				            AND de_cond.action = ac.expected_action
				      )
				)

			AND (
			    a.allowed_roles IS NULL
			    OR jsonb_exists(a.allowed_roles, rp.role)
			)

			ORDER BY openAt
			""", nativeQuery = true)
	List<VisibleArtifactView> findVisibleArtifacts(@Param("runId") UUID runId,
			@Param("participantId") UUID participantId);

	// =========================
	// Sim 1 multi-round progression (per-round timeline, CEO-gated advancement)
	// =========================

	/** Activate a round for a run (used when the run starts, and on each advance). */
	@Modifying
	@Query(value = """
			INSERT INTO sim1_round_state (run_id, round_number, status, started_at)
			VALUES (:runId, :roundNumber, 'ACTIVE', now())
			ON CONFLICT (run_id, round_number)
			DO UPDATE SET status = 'ACTIVE', started_at = now()
			""", nativeQuery = true)
	void activateSim1Round(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	@Modifying
	@Query(value = """
			UPDATE sim1_round_state SET status = 'COMPLETE'
			WHERE run_id = :runId AND round_number = :roundNumber
			""", nativeQuery = true)
	void completeSim1Round(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	@Modifying
	@Query(value = "UPDATE simulation_runs SET status = 'COMPLETED' WHERE run_id = :runId",
			nativeQuery = true)
	void completeRun(@Param("runId") UUID runId);

	/** The round a given artifact belongs to. */
	@Query(value = """
			SELECT r.round_number FROM artifacts a
			JOIN rounds r ON r.round_id = a.round_id
			WHERE a.artifact_id = :artifactId
			""", nativeQuery = true)
	Integer findRoundNumberByArtifact(@Param("artifactId") UUID artifactId);

	/** The next round number for a run's simulation after {@code current}, or null if none. */
	@Query(value = """
			SELECT MIN(r.round_number) FROM rounds r
			JOIN simulation_runs sr ON sr.simulation_id = r.simulation_id
			WHERE sr.run_id = :runId AND r.round_number > :current
			""", nativeQuery = true)
	Integer findNextRoundNumber(@Param("runId") UUID runId, @Param("current") int current);

	/** The active round of a run, with its start time and the simulation's round count. */
	@Query(value = """
			SELECT rs.round_number AS "roundNumber",
			       rs.started_at   AS "startedAt",
			       rs.status       AS "status",
			       (SELECT count(*)::int FROM rounds r WHERE r.simulation_id = sr.simulation_id) AS "totalRounds",
			       (SELECT r.duration_minutes FROM rounds r
			         WHERE r.simulation_id = sr.simulation_id AND r.round_number = rs.round_number) AS "durationMinutes"
			FROM sim1_round_state rs
			JOIN simulation_runs sr ON sr.run_id = rs.run_id
			WHERE rs.run_id = :runId AND rs.status = 'ACTIVE'
			LIMIT 1
			""", nativeQuery = true)
	Map<String, Object> findSim1ActiveRound(@Param("runId") UUID runId);

	// =========================
	// READ: facilitator-injected artifacts for this run (surfaced to students)
	// =========================
	@Query(value = """
			SELECT injection_id AS "injectionId",
			       round_number AS "roundNumber",
			       title        AS "title",
			       content      AS "content",
			       injected_at  AS "injectedAt"
			FROM run_injected_artifacts
			WHERE run_id = :runId
			ORDER BY injected_at
			""", nativeQuery = true)
	List<Map<String, Object>> findInjectedArtifacts(@Param("runId") UUID runId);

	// =========================
	// READ: participant role
	// =========================
	@Query(value = """
			SELECT rp.role
			FROM run_participants rp
			WHERE rp.run_participant_id = :participantId
			  AND rp.run_id = :runId
			""", nativeQuery = true)
	String findParticipantRole(@Param("runId") UUID runId, @Param("participantId") UUID participantId);

	// =========================
	// READ: decision metadata
	// =========================
	@Query(value = """
			SELECT
			  d.decision_id AS decisionId,
			  d.decision_type AS decisionType,
			  d.is_final AS isFinal,
			  d.allowed_roles::text AS allowedRoles
			FROM decisions d
			WHERE d.decision_id = :decisionId
			""", nativeQuery = true)
	DecisionMetaView findDecisionMeta(@Param("decisionId") UUID decisionId);

	// =========================
	// READ: duplicate check
	// =========================
	@Query(value = """
			SELECT count(*)
			FROM decision_events de
			WHERE de.run_id = :runId
			  AND de.run_participant_id = :participantId
			  AND de.decision_id = :decisionId
			""", nativeQuery = true)
	int countExistingDecision(@Param("runId") UUID runId, @Param("participantId") UUID participantId,
			@Param("decisionId") UUID decisionId);

	// =========================
	// WRITE: insert decision
	// =========================
	@Modifying
	@Query(value = """
			INSERT INTO decision_events (
			    decision_event_id,
			    run_id,
			    run_participant_id,
			    artifact_id,
			    decision_id,
			    action,
			    decision_type,
			    latency_band,
			    decided_at
			) VALUES (
			    uuid_generate_v4(),
			    :runId,
			    :participantId,
			    :artifactId,
			    :decisionId,
			    :action,
			    :decisionType,
			    :latencyBand,
			    :decidedAt
			)
			""", nativeQuery = true)
	void insertDecisionEvent(@Param("runId") UUID runId, @Param("participantId") UUID participantId,
			@Param("artifactId") UUID artifactId, @Param("decisionId") UUID decisionId, @Param("action") String action,
			@Param("decisionType") String decisionType, @Param("latencyBand") String latencyBand,
			@Param("decidedAt") LocalDateTime decidedAt);

	@Query(value = """
			    SELECT
			      a.artifact_id,
			      d.decision_id
			    FROM simulation_runs sr

			    JOIN run_participants rp
			      ON rp.run_id = sr.run_id
			     AND rp.run_participant_id = :participantId

			    JOIN rounds r ON r.simulation_id = sr.simulation_id
			    JOIN artifacts a ON a.round_id = r.round_id
			    JOIN decisions d ON d.artifact_id = a.artifact_id

			    WHERE sr.run_id = :runId

			      AND d.decision_id IS NOT NULL

			      AND now() >= (sr.started_at + (a.expiry_offset_min || ' minutes')::interval)

			      AND NOT EXISTS (
			          SELECT 1
			          FROM decision_events de
			          WHERE de.run_id = sr.run_id
			            AND de.run_participant_id = rp.run_participant_id
			            AND de.decision_id = d.decision_id
			      )
			""", nativeQuery = true)
	List<Object[]> findExpiredUnansweredDecisions(@Param("runId") UUID runId,
			@Param("participantId") UUID participantId);

	@Query(value = """
			    SELECT
			      de.run_participant_id AS participantId,
			      SUM(o.trust_delta)      AS trust,
			      SUM(o.risk_delta)       AS risk,
			      SUM(o.ethics_delta)     AS ethics,
			      SUM(o.execution_delta)  AS execution
			    FROM decision_events de
			    JOIN decision_options o
			      ON o.decision_id = de.decision_id
			     AND o.action = de.action
			    WHERE de.run_id = :runId
			    GROUP BY de.run_participant_id
			""", nativeQuery = true)
	List<Object[]> computeScores(@Param("runId") UUID runId);

	@Query(value = """
			    SELECT d.artifact_id
			    FROM decisions d
			    WHERE d.decision_id = :decisionId
			""", nativeQuery = true)
	UUID findArtifactIdByDecisionId(@Param("decisionId") UUID decisionId);

	@Query(value = """
			SELECT COUNT(*) FROM decision_options
			WHERE decision_id = :decisionId
			AND action = :action
			""", nativeQuery = true)
	int countValidOption(@Param("decisionId") UUID decisionId, @Param("action") String action);

	@Query(value = """
			SELECT sr.started_at + (a.open_offset_min || ' minutes')::interval AS openAt,
			       sr.started_at + (a.expiry_offset_min || ' minutes')::interval AS expiresAt
			FROM artifacts a
			JOIN rounds r ON r.round_id = a.round_id
			JOIN simulation_runs sr ON sr.simulation_id = r.simulation_id
			WHERE a.artifact_id = :artifactId
			  AND sr.run_id = :runId
			""", nativeQuery = true)
	Object[] findArtifactWindow(@Param("artifactId") UUID artifactId, @Param("runId") UUID runId);

	@Modifying
	@Query(value = """
			INSERT INTO run_construct_state (run_id, run_participant_id, construct_name, value, updated_at)
			VALUES
			  (:runId, :participantId, 'stakeholder_trust',
			    50 + (SELECT trust_delta FROM decision_options WHERE decision_id = :decisionId AND action = :action), now()),

			  (:runId, :participantId, 'organizational_risk',
			    50 + (SELECT risk_delta FROM decision_options WHERE decision_id = :decisionId AND action = :action), now()),

			  (:runId, :participantId, 'ethical_exposure',
			    50 + (SELECT ethics_delta FROM decision_options WHERE decision_id = :decisionId AND action = :action), now()),

			  (:runId, :participantId, 'execution_quality',
			    50 + (SELECT execution_delta FROM decision_options WHERE decision_id = :decisionId AND action = :action), now())

			ON CONFLICT (run_id, run_participant_id, construct_name)
			DO UPDATE SET
			  value = LEAST(100, GREATEST(0, run_construct_state.value + EXCLUDED.value - 50)),
			  updated_at = now()
			""", nativeQuery = true)
	void applyConstructDeltas(@Param("runId") UUID runId, @Param("participantId") UUID participantId,
			@Param("decisionId") UUID decisionId, @Param("action") String action);

	@Query(value = """
			    SELECT construct_name, value
			    FROM run_construct_state
			    WHERE run_id = :runId
			      AND run_participant_id = :participantId
			""", nativeQuery = true)
	List<Object[]> getParticipantResults(@Param("runId") UUID runId, @Param("participantId") UUID participantId);

	@Query(value = """
			    SELECT construct_name, AVG(value)
			    FROM run_construct_state
			    WHERE run_id = :runId
			    GROUP BY construct_name
			""", nativeQuery = true)
	List<Object[]> getTeamResults(@Param("runId") UUID runId);
	
	@Modifying
	@Query(value = """
	    INSERT INTO simulation_runs 
	    (run_id, simulation_id, started_at, team_name, team_id, status)
	    VALUES (:runId, :simulationId, now(), :teamName, :teamId, 'ACTIVE')
	""", nativeQuery = true)
	void createRun(
	    @Param("runId") UUID runId,
	    @Param("simulationId") UUID simulationId,
	    @Param("teamName") String teamName,
	    @Param("teamId") UUID teamId
	);
	
	@Modifying
	@Query(value = """
	    INSERT INTO run_participants (run_id, run_participant_id, role)
	    VALUES (:runId, :participantId, :role)
	""", nativeQuery = true)
	void addParticipant(
	    @Param("runId") UUID runId,
	    @Param("participantId") UUID participantId,
	    @Param("role") String role
	);
	
	@Query(value = """
		    SELECT * FROM simulation_runs 
		    WHERE team_id = :teamId
		    LIMIT 1
		""", nativeQuery = true)
		Map<String, Object> getRunByTeam(@Param("teamId") UUID teamId);
	
	
	@Query(value = """
		    SELECT participant_id AS "participantId", role
		    FROM participant
		    WHERE team_id = :teamId
		""", nativeQuery = true)
		List<Map<String, Object>> getParticipantsByTeam(@Param("teamId") UUID teamId);

	// =========================
	// Sim 1 — 1.2 News interrupt, 1.7 CEO timeout, 1.10 post-round interstitial
	// =========================

	/** Records a News broadcast for a run's round (1.2). Slides the schedule for pause_seconds. */
	@Modifying
	@Query(value = """
			INSERT INTO sim1_news (run_id, round_number, headline, body, pause_seconds)
			VALUES (:runId, :roundNumber, :headline, :body, :pauseSeconds)
			""", nativeQuery = true)
	void insertNews(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber,
			@Param("headline") String headline, @Param("body") String body,
			@Param("pauseSeconds") int pauseSeconds);

	/** The News interrupt still on screen for a run's active round, if any (1.2). */
	@Query(value = """
			SELECT n.headline AS "headline",
			       n.body     AS "body",
			       CEIL(n.pause_seconds - EXTRACT(EPOCH FROM (now() - n.created_at)))::int AS "secondsLeft"
			FROM sim1_news n
			WHERE n.run_id = :runId AND n.round_number = :roundNumber
			  AND now() < n.created_at + (n.pause_seconds || ' seconds')::interval
			ORDER BY n.created_at DESC
			LIMIT 1
			""", nativeQuery = true)
	Map<String, Object> findActiveNews(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	/** Total paused seconds for a round — faculty pause plus any News slide — matching the schedule. */
	@Query(value = """
			SELECT COALESCE(rc.paused_seconds_total, 0)
			     + COALESCE(EXTRACT(EPOCH FROM (now() - rc.paused_at))::int, 0)
			     + COALESCE((SELECT SUM(LEAST(EXTRACT(EPOCH FROM (now() - n.created_at)), n.pause_seconds))::int
			                 FROM sim1_news n
			                 WHERE n.run_id = :runId AND n.round_number = :roundNumber), 0)
			FROM (SELECT 1) x
			LEFT JOIN run_round_clock rc ON rc.run_id = :runId AND rc.round_number = :roundNumber
			""", nativeQuery = true)
	Integer findPausedSeconds(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	/** Whether the CEO's final decision for a round has been recorded (1.7 / 1.10). */
	@Query(value = """
			SELECT count(*) FROM decision_events de
			JOIN decisions d ON d.decision_id = de.decision_id AND d.is_final
			JOIN artifacts a ON a.artifact_id = d.artifact_id
			JOIN rounds r ON r.round_id = a.round_id
			JOIN simulation_runs sr ON sr.simulation_id = r.simulation_id AND sr.run_id = de.run_id
			WHERE de.run_id = :runId AND r.round_number = :roundNumber
			""", nativeQuery = true)
	int countFinalDecision(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	/** The CEO's submitted framing for a round: chosen action code and its option label (1.10). */
	@Query(value = """
			SELECT de.action AS "action",
			       (SELECT opt->>'label' FROM jsonb_array_elements(d.options) opt
			         WHERE opt->>'id' = de.action LIMIT 1) AS "label"
			FROM decision_events de
			JOIN decisions d ON d.decision_id = de.decision_id AND d.is_final
			JOIN artifacts a ON a.artifact_id = d.artifact_id
			JOIN rounds r ON r.round_id = a.round_id
			JOIN simulation_runs sr ON sr.simulation_id = r.simulation_id AND sr.run_id = de.run_id
			WHERE de.run_id = :runId AND r.round_number = :roundNumber
			LIMIT 1
			""", nativeQuery = true)
	Map<String, Object> findFinalFraming(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	/** Every currently-active Sim-1 round, for the timeout scanner (1.7). */
	@Query(value = """
			SELECT rs.run_id AS "runId",
			       rs.round_number AS "roundNumber",
			       rs.started_at AS "startedAt",
			       (SELECT r.duration_minutes FROM rounds r
			          WHERE r.simulation_id = sr.simulation_id AND r.round_number = rs.round_number) AS "durationMinutes"
			FROM sim1_round_state rs
			JOIN simulation_runs sr ON sr.run_id = rs.run_id
			WHERE rs.status = 'ACTIVE' AND sr.status = 'ACTIVE'
			""", nativeQuery = true)
	List<Map<String, Object>> findActiveSim1Rounds();

	/** The run's CEO participant id — the party accountable for a missed final decision (1.7). */
	@Query(value = """
			SELECT rp.run_participant_id FROM run_participants rp
			WHERE rp.run_id = :runId AND rp.role = 'CEO' LIMIT 1
			""", nativeQuery = true)
	UUID findCeoParticipant(@Param("runId") UUID runId);

	/** Records the auto-advance in the faculty action log as "No decision submitted" (1.7). */
	@Modifying
	@Query(value = """
			INSERT INTO faculty_actions
			  (action_id, simulation_id, run_id, team_id, round_number, action_type, scope, note, created_by, created_at)
			SELECT gen_random_uuid(), sr.simulation_id, sr.run_id, sr.team_id, :roundNumber,
			       'TIMEOUT', 'TEAM', 'No decision submitted', 'system', now()
			FROM simulation_runs sr WHERE sr.run_id = :runId
			""", nativeQuery = true)
	void logTimeout(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	/** Applies the "No decision submitted" penalty to the CEO's Trust and Execution state (1.7). */
	@Modifying
	@Query(value = """
			INSERT INTO run_construct_state (run_id, run_participant_id, construct_name, value, updated_at)
			VALUES
			  (:runId, :participantId, 'stakeholder_trust', 50 + :trustDelta, now()),
			  (:runId, :participantId, 'execution_quality', 50 + :execDelta, now())
			ON CONFLICT (run_id, run_participant_id, construct_name)
			DO UPDATE SET
			  value = LEAST(100, GREATEST(0, run_construct_state.value + EXCLUDED.value - 50)),
			  updated_at = now()
			""", nativeQuery = true)
	void applyTimeoutPenalty(@Param("runId") UUID runId, @Param("participantId") UUID participantId,
			@Param("trustDelta") int trustDelta, @Param("execDelta") int execDelta);

}
