package com.example.simulator.sim1;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.simulator.simulation.SimulationRun;

/**
 * Read side of the Simulator 1 team report — the roster, the round-by-round CEO framings and the full
 * decision trail behind a single run.
 *
 * <p>Kept apart from the two debrief repositories because the report is the only place these three
 * things are needed together, and because it is served to STUDENTS as well as faculty: every query here
 * is scoped to one run and returns nothing a team should not see about itself.
 */
@Repository
public interface Sim1ReportRepository
		extends org.springframework.data.repository.Repository<SimulationRun, UUID> {

	/** Run header: team name, when it started, and its lifecycle status. */
	@Query(value = """
			SELECT sr.run_id        AS "runId",
			       sr.team_name     AS "teamName",
			       sr.started_at    AS "startedAt",
			       sr.status        AS "status",
			       sr.simulation_id AS "simulationId",
			       s.name           AS "simulationName"
			FROM simulation_runs sr
			JOIN simulations s ON s.simulation_id = sr.simulation_id
			WHERE sr.run_id = :runId
			""", nativeQuery = true)
	Map<String, Object> findRunHeader(@Param("runId") UUID runId);

	/**
	 * Per participant: how many decisions they actually answered and how many expired unanswered.
	 * A No Response is stored in decision_events as the action SILENCE, so both come from one scan
	 * and "addressed" is simply the sum — there is no separate notion of a decision they never saw.
	 */
	@Query(value = """
			SELECT rp.run_participant_id AS "participantId",
			       rp.role               AS "role",
			       p.name                AS "name",
			       COALESCE(SUM(CASE WHEN de.action <> 'SILENCE' THEN 1 ELSE 0 END), 0)::int AS "answered",
			       COALESCE(SUM(CASE WHEN de.action  = 'SILENCE' THEN 1 ELSE 0 END), 0)::int AS "noResponses"
			FROM run_participants rp
			LEFT JOIN participant p ON p.participant_id = rp.run_participant_id
			LEFT JOIN decision_events de
			       ON de.run_id = rp.run_id AND de.run_participant_id = rp.run_participant_id
			WHERE rp.run_id = :runId
			GROUP BY rp.run_participant_id, rp.role, p.name
			ORDER BY rp.role
			""", nativeQuery = true)
	List<Map<String, Object>> findRoster(@Param("runId") UUID runId);

	/**
	 * The full decision trail for a run, in play order. The chosen option label is read out of the
	 * decision JSON so the report can print the words the participant actually clicked rather than the
	 * option code. SILENCE rows carry no label and are rendered as No Response by the caller.
	 */
	@Query(value = """
			SELECT r.round_number       AS "round",
			       a.payload->>'title'  AS "artifactTitle",
			       rp.role              AS "role",
			       p.name               AS "name",
			       de.action            AS "action",
			       de.decided_at        AS "decidedAt",
			       d.is_final           AS "isFinal",
			       d.decision_type      AS "decisionType",
			       a.open_offset_min    AS "openOffsetMin",
			       (SELECT opt->>'label' FROM jsonb_array_elements(d.options) opt
			         WHERE opt->>'id' = de.action LIMIT 1) AS "label"
			FROM decision_events de
			JOIN decisions d       ON d.decision_id = de.decision_id
			JOIN artifacts a       ON a.artifact_id = de.artifact_id
			JOIN rounds r          ON r.round_id = a.round_id
			JOIN run_participants rp
			       ON rp.run_id = de.run_id AND rp.run_participant_id = de.run_participant_id
			LEFT JOIN participant p ON p.participant_id = rp.run_participant_id
			WHERE de.run_id = :runId
			ORDER BY r.round_number, a.open_offset_min, de.decided_at
			""", nativeQuery = true)
	List<Map<String, Object>> findDecisionTrail(@Param("runId") UUID runId);

	/** How many rounds this run actually reached, and when the last one started. */
	@Query(value = """
			SELECT COALESCE(MAX(rs.round_number), 0)::int
			FROM sim1_round_state rs
			WHERE rs.run_id = :runId
			""", nativeQuery = true)
	int findRoundsReached(@Param("runId") UUID runId);
}
