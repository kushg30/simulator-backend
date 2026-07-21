package com.example.simulator.faculty;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.simulator.simulation.SimulationRun;

/**
 * Data access for the platform-wide faculty control layer.
 *
 * <p>Nothing here is specific to a simulation: every query is keyed by run and round, so the same
 * controls work for Simulation 1, Simulator 2 and anything added later.
 */
@Repository
public interface FacultyRepository extends org.springframework.data.repository.Repository<SimulationRun, UUID> {

	// =========================================================================
	// Run clock (pause / resume)
	// =========================================================================

	/** Starts a pause. No-op if the round is already paused, so pausing twice is safe. */
	@Modifying
	@Query(value = """
			INSERT INTO run_round_clock (run_id, round_number, paused_seconds_total, paused_at, updated_at)
			VALUES (:runId, :roundNumber, 0, now(), now())
			ON CONFLICT (run_id, round_number) DO UPDATE
			SET paused_at = COALESCE(run_round_clock.paused_at, now()),
			    updated_at = now()
			""", nativeQuery = true)
	void pause(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	/**
	 * Ends a pause, folding its duration into the accumulated total. No-op when not paused, so a
	 * duplicate resume cannot inflate the total.
	 */
	@Modifying
	@Query(value = """
			UPDATE run_round_clock
			SET paused_seconds_total = paused_seconds_total
			        + GREATEST(0, EXTRACT(EPOCH FROM (now() - paused_at))::int),
			    paused_at = NULL,
			    updated_at = now()
			WHERE run_id = :runId AND round_number = :roundNumber AND paused_at IS NOT NULL
			""", nativeQuery = true)
	void resume(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	@Query(value = """
			SELECT paused_seconds_total AS "pausedSecondsTotal",
			       paused_at            AS "pausedAt",
			       (paused_at IS NOT NULL) AS "paused"
			FROM run_round_clock
			WHERE run_id = :runId AND round_number = :roundNumber
			""", nativeQuery = true)
	Map<String, Object> findClock(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	/** Every currently-active round of a simulation — the target set for an all-teams action. */
	@Query(value = """
			SELECT rs.run_id AS "runId", rs.round_number AS "roundNumber", sr.team_name AS "teamName"
			FROM sim2_round_state rs
			JOIN simulation_runs sr ON sr.run_id = rs.run_id
			WHERE sr.simulation_id = :simulationId AND rs.status = 'ACTIVE'
			""", nativeQuery = true)
	List<Map<String, Object>> findActiveRounds(@Param("simulationId") UUID simulationId);

	@Query(value = "SELECT simulation_id FROM simulation_runs WHERE run_id = :runId", nativeQuery = true)
	UUID findSimulationId(@Param("runId") UUID runId);

	@Query(value = "SELECT team_id FROM simulation_runs WHERE run_id = :runId", nativeQuery = true)
	UUID findTeamId(@Param("runId") UUID runId);

	// =========================================================================
	// Action log
	// =========================================================================

	@Modifying
	@Query(value = """
			INSERT INTO faculty_actions (simulation_id, run_id, team_id, round_number, action_type,
			                             scope, target_artifact, delay_minutes, injected_content,
			                             note, created_by)
			VALUES (:simulationId, :runId, :teamId, :roundNumber, :actionType, :scope,
			        :targetArtifact, :delayMinutes, CAST(:injectedContent AS jsonb), :note, :createdBy)
			""", nativeQuery = true)
	void logAction(@Param("simulationId") UUID simulationId, @Param("runId") UUID runId,
			@Param("teamId") UUID teamId, @Param("roundNumber") Integer roundNumber,
			@Param("actionType") String actionType, @Param("scope") String scope,
			@Param("targetArtifact") UUID targetArtifact, @Param("delayMinutes") Integer delayMinutes,
			@Param("injectedContent") String injectedContent, @Param("note") String note,
			@Param("createdBy") String createdBy);

	@Query(value = """
			SELECT fa.action_id AS "actionId", fa.run_id AS "runId", fa.team_id AS "teamId",
			       fa.round_number AS "roundNumber", fa.action_type AS "actionType",
			       fa.scope AS "scope", fa.target_artifact AS "targetArtifact",
			       fa.delay_minutes AS "delayMinutes", fa.note AS "note",
			       fa.created_by AS "createdBy", fa.created_at AS "createdAt"
			FROM faculty_actions fa
			WHERE (:runId IS NULL OR fa.run_id = :runId)
			ORDER BY fa.created_at DESC
			LIMIT 200
			""", nativeQuery = true)
	List<Map<String, Object>> findActions(@Param("runId") UUID runId);
}
