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
	@Query(value = """
			SELECT
			  a.artifact_id AS artifactId,
			  a.artifact_type AS artifactType,
			  a.payload::text AS payload,
			  a.expected_action AS expectedAction,
			  r.round_number AS roundNumber,
			  (sr.started_at + (a.open_offset_min || ' minutes')::interval) AS openAt,
			  (sr.started_at + (a.expiry_offset_min || ' minutes')::interval) AS expiresAt,
			  d.decision_id AS decisionId,
			  d.decision_type AS decisionType,
			  d.options::text AS decisionOptions,
			  de.action AS chosenAction,
			  d.allowed_roles::text AS allowedRoles,

			  CASE
			    WHEN de.decision_event_id IS NOT NULL THEN 'ACTED'
			    WHEN now() >= (sr.started_at + (a.expiry_offset_min || ' minutes')::interval) THEN 'EXPIRED'
			    WHEN d.decision_id IS NOT NULL THEN 'OPEN'
			    ELSE 'READ_ONLY'
			  END AS actionState

			FROM simulation_runs sr

			JOIN run_participants rp
			  ON rp.run_id = sr.run_id
			 AND rp.run_participant_id = :participantId

			JOIN rounds r ON r.simulation_id = sr.simulation_id
			JOIN artifacts a ON a.round_id = r.round_id

			LEFT JOIN decisions d ON d.artifact_id = a.artifact_id

			LEFT JOIN decision_events de
			  ON de.artifact_id = a.artifact_id
			 AND de.run_id = sr.run_id
			 AND de.run_participant_id = :participantId


			LEFT JOIN artifact_conditions ac
			  ON ac.artifact_id = a.artifact_id

			LEFT JOIN decision_events de_cond
			  ON de_cond.decision_id = ac.depends_on_decision_id
			 AND de_cond.run_id = sr.run_id
			 AND de_cond.run_participant_id = :participantId
			 AND de_cond.action = ac.expected_action

			WHERE sr.run_id = :runId

			AND now() >= (sr.started_at + (a.open_offset_min || ' minutes')::interval)

			AND (
			    a.allowed_roles IS NULL
			    OR jsonb_exists(a.allowed_roles, rp.role)
			)


			AND (
			    ac.id IS NULL
			    OR de_cond.decision_event_id IS NOT NULL
			)

			ORDER BY openAt
			""", nativeQuery = true)
	List<VisibleArtifactView> findVisibleArtifacts(@Param("runId") UUID runId,
			@Param("participantId") UUID participantId);

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
	
}
