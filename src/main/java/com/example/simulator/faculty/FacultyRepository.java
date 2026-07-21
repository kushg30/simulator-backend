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

	// =========================================================================
	// Session overview — what the facilitator sees on the console
	// =========================================================================

	/**
	 * One row per TEAM, not per team-round.
	 *
	 * <p>A facilitator scans this list looking for teams, so a team must appear once showing the
	 * round it is actually on: the round in play if there is one, otherwise the most recent. The
	 * earlier version emitted a row per (team, round) pair, which made a team on round 5 appear
	 * five times. Live teams sort to the top since those are the ones that can be acted on.
	 */
	@Query(value = """
			SELECT * FROM (
			  SELECT DISTINCT ON (sr.run_id)
			         sr.run_id        AS "runId",
			         sr.team_name     AS "teamName",
			         s.name           AS "simulationName",
			         sr.simulation_id AS "simulationId",
			         s.total_rounds   AS "totalRounds",
			         rs.round_number  AS "roundNumber",
			         rs.status        AS "roundStatus",
			         rs.started_at    AS "startedAt",
			         COALESCE(rc.paused_seconds_total, 0) AS "pausedSecondsTotal",
			         (rc.paused_at IS NOT NULL)           AS "paused",
			         EXISTS (SELECT 1 FROM run_round_bypass b
			                  WHERE b.run_id = sr.run_id AND b.round_number = rs.round_number) AS "bypassed",
			         (SELECT count(*) FROM sim2_round_state c
			           WHERE c.run_id = sr.run_id AND c.status = 'COMPLETE') AS "roundsComplete"
			  FROM simulation_runs sr
			  JOIN simulations s ON s.simulation_id = sr.simulation_id
			  JOIN sim2_round_state rs ON rs.run_id = sr.run_id
			  LEFT JOIN run_round_clock rc ON rc.run_id = rs.run_id
			                              AND rc.round_number = rs.round_number
			  ORDER BY sr.run_id,
			           -- prefer the round in play, then the furthest one reached
			           CASE rs.status WHEN 'ACTIVE' THEN 0 WHEN 'PENDING' THEN 1 ELSE 2 END,
			           rs.round_number DESC
			) t
			ORDER BY (t."roundStatus" = 'ACTIVE') DESC, t."teamName"
			LIMIT 100
			""", nativeQuery = true)
	List<Map<String, Object>> findSessionOverview();

	/** Artifacts authored for a round, with any override already applied — delay/bypass targets. */
	@Query(value = """
			SELECT a.artifact_id     AS "artifactId",
			       a.artifact_type   AS "artifactType",
			       a.open_offset_min AS "openOffsetMin",
			       COALESCE(ov.delay_minutes, 0) AS "delayMinutes",
			       COALESCE(ov.bypassed, false)  AS "bypassed",
			       a.payload ->> 'title'         AS "title"
			FROM simulation_runs sr
			JOIN rounds r    ON r.simulation_id = sr.simulation_id AND r.round_number = :roundNumber
			JOIN artifacts a ON a.round_id = r.round_id
			LEFT JOIN run_artifact_overrides ov ON ov.run_id = sr.run_id
			                                   AND ov.artifact_id = a.artifact_id
			WHERE sr.run_id = :runId
			ORDER BY a.open_offset_min
			""", nativeQuery = true)
	List<Map<String, Object>> findRoundArtifacts(@Param("runId") UUID runId,
			@Param("roundNumber") int roundNumber);

	// =========================================================================
	// Delay — shifts the target artifact AND everything scheduled after it in
	// that round by the same amount, which is the clock-shift behaviour the
	// spec asks for rather than re-authoring the schedule.
	// =========================================================================

	@Modifying
	@Query(value = """
			INSERT INTO run_artifact_overrides (run_id, artifact_id, delay_minutes, updated_at)
			SELECT sr.run_id, a.artifact_id, :delayMinutes, now()
			FROM simulation_runs sr
			JOIN rounds r    ON r.simulation_id = sr.simulation_id AND r.round_number = :roundNumber
			JOIN artifacts a ON a.round_id = r.round_id
			WHERE sr.run_id = :runId
			  AND a.open_offset_min >= (SELECT a2.open_offset_min FROM artifacts a2
			                             WHERE a2.artifact_id = :artifactId)
			ON CONFLICT (run_id, artifact_id) DO UPDATE
			SET delay_minutes = run_artifact_overrides.delay_minutes + EXCLUDED.delay_minutes,
			    updated_at = now()
			""", nativeQuery = true)
	void delayFrom(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber,
			@Param("artifactId") UUID artifactId, @Param("delayMinutes") int delayMinutes);

	// =========================================================================
	// Bypass
	// =========================================================================

	/** Skips one artifact. Its micro-decision and any conditional trigger never fire. */
	@Modifying
	@Query(value = """
			INSERT INTO run_artifact_overrides (run_id, artifact_id, bypassed, updated_at)
			VALUES (:runId, :artifactId, true, now())
			ON CONFLICT (run_id, artifact_id) DO UPDATE
			SET bypassed = true, updated_at = now()
			""", nativeQuery = true)
	void bypassArtifact(@Param("runId") UUID runId, @Param("artifactId") UUID artifactId);

	/**
	 * Skips a whole round. It is EXCLUDED from the construct rollup rather than scored zero: a
	 * bypassed round is treated as not attempted, not as failed.
	 */
	@Modifying
	@Query(value = """
			INSERT INTO run_round_bypass (run_id, round_number, reason)
			VALUES (:runId, :roundNumber, :reason)
			ON CONFLICT (run_id, round_number) DO UPDATE SET reason = EXCLUDED.reason
			""", nativeQuery = true)
	void bypassRound(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber,
			@Param("reason") String reason);

	@Modifying
	@Query(value = """
			UPDATE sim2_round_state SET status = 'BYPASSED'
			WHERE run_id = :runId AND round_number = :roundNumber
			""", nativeQuery = true)
	void markRoundBypassed(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber);

	// =========================================================================
	// Injection
	// =========================================================================

	@Query(value = """
			SELECT catalogue_id AS "catalogueId", round_number AS "roundNumber", title AS "title",
			       content AS "content", tier AS "tier", canonical_answer AS "canonicalAnswer",
			       effect AS "effect"
			FROM catalogue_artifacts
			WHERE simulation_id = :simulationId
			ORDER BY round_number, title
			""", nativeQuery = true)
	List<Map<String, Object>> findCatalogue(@Param("simulationId") UUID simulationId);

	@Modifying
	@Query(value = """
			INSERT INTO run_injected_artifacts (run_id, round_number, catalogue_id, title, content,
			                                    tier, scored, canonical_answer)
			VALUES (:runId, :roundNumber, :catalogueId, :title, :content, :tier, :scored, :canonicalAnswer)
			""", nativeQuery = true)
	void injectArtifact(@Param("runId") UUID runId, @Param("roundNumber") int roundNumber,
			@Param("catalogueId") UUID catalogueId, @Param("title") String title,
			@Param("content") String content, @Param("tier") String tier,
			@Param("scored") boolean scored, @Param("canonicalAnswer") String canonicalAnswer);

	@Query(value = """
			SELECT catalogue_id AS "catalogueId", title AS "title", content AS "content",
			       tier AS "tier", canonical_answer AS "canonicalAnswer"
			FROM catalogue_artifacts WHERE catalogue_id = :catalogueId
			""", nativeQuery = true)
	Map<String, Object> findCatalogueEntry(@Param("catalogueId") UUID catalogueId);

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
