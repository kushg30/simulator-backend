package com.example.simulator.sim2;

import java.util.Map;
import java.util.UUID;

import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.simulator.simulation.SimulationRun;

/**
 * Data access for the Simulator 2 v2 engagement devices: facilitator broadcasts
 * (Breaking News) and the Emergency Board Call one-line team responses.
 */
@Repository
public interface Sim2EngagementRepository
		extends org.springframework.data.repository.Repository<SimulationRun, UUID> {

	@Modifying
	@Query(value = """
			INSERT INTO sim2_broadcast (simulation_id, kind, message, created_by)
			VALUES (:simulationId, :kind, :message, :createdBy)
			""", nativeQuery = true)
	void insertBroadcast(@Param("simulationId") UUID simulationId, @Param("kind") String kind,
			@Param("message") String message, @Param("createdBy") String createdBy);

	/** The most recent broadcast for a simulation (or null), for students to poll. */
	@Query(value = """
			SELECT broadcast_id AS "broadcastId", kind AS "kind", message AS "message",
			       created_at AS "createdAt"
			FROM sim2_broadcast
			WHERE simulation_id = :simulationId
			ORDER BY created_at DESC
			LIMIT 1
			""", nativeQuery = true)
	Map<String, Object> findLatestBroadcast(@Param("simulationId") UUID simulationId);

	@Modifying
	@Query(value = """
			INSERT INTO sim2_board_call (run_id, round_number, participant_id, response)
			VALUES (:runId, :roundNumber, :participantId, :response)
			ON CONFLICT (run_id, round_number)
			DO UPDATE SET response = EXCLUDED.response,
			              participant_id = EXCLUDED.participant_id,
			              created_at = now()
			""", nativeQuery = true)
	void upsertBoardCall(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber,
			@Param("participantId") UUID participantId, @Param("response") String response);

	@Query(value = """
			SELECT response AS "response", created_at AS "createdAt"
			FROM sim2_board_call
			WHERE run_id = :runId AND round_number = :roundNumber
			""", nativeQuery = true)
	Map<String, Object> findBoardCall(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	@Query(value = "SELECT simulation_id FROM simulation_runs WHERE run_id = :runId", nativeQuery = true)
	UUID findSimulationId(@Param("runId") UUID runId);

	/**
	 * The latest broadcast for this run's simulation that was sent AFTER the run started, so a stale
	 * broadcast from an earlier session never fires for a team that started later.
	 */
	@Query(value = """
			SELECT b.broadcast_id AS "broadcastId", b.kind AS "kind", b.message AS "message",
			       b.created_at AS "createdAt"
			FROM sim2_broadcast b
			JOIN simulation_runs sr ON sr.simulation_id = b.simulation_id
			WHERE sr.run_id = :runId
			  AND b.created_at > sr.started_at
			ORDER BY b.created_at DESC
			LIMIT 1
			""", nativeQuery = true)
	Map<String, Object> findLatestBroadcastForRun(@Param("runId") UUID runId);

	/** The team's Round 2 typed answer (training vs market), used to personalise Breaking News. */
	@Query(value = "SELECT typed_answer FROM sim2_submissions WHERE run_id = :runId AND round_number = 2",
			nativeQuery = true)
	String findRound2Answer(@Param("runId") UUID runId);
}
