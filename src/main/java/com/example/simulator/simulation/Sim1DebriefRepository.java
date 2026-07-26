package com.example.simulator.simulation;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

/**
 * Read side of the Simulator 1 faculty debrief.
 *
 * <p>Simulator 1's engine records the four hidden variables (Set A) per participant in
 * {@code run_construct_state}. This returns one row per (team, participant, construct) so the
 * service can roll them up to team level. Kept separate from the Sim 2 debrief because the two
 * simulations score entirely different constructs.
 */
@Repository
public interface Sim1DebriefRepository
		extends org.springframework.data.repository.Repository<SimulationRun, UUID> {

	@Query(value = """
			SELECT sr.run_id               AS "runId",
			       sr.team_name            AS "teamName",
			       sr.started_at           AS "startedAt",
			       rp.run_participant_id   AS "participantId",
			       rp.role                 AS "role",
			       p.name                  AS "name",
			       rcs.construct_name      AS "construct",
			       rcs.value               AS "value"
			FROM simulation_runs sr
			JOIN run_participants rp        ON rp.run_id = sr.run_id
			LEFT JOIN participant p         ON p.participant_id = rp.run_participant_id
			LEFT JOIN run_construct_state rcs
			       ON rcs.run_id = sr.run_id
			      AND rcs.run_participant_id = rp.run_participant_id
			WHERE sr.simulation_id = :simulationId
			ORDER BY sr.started_at DESC, sr.run_id, rp.role
			""", nativeQuery = true)
	List<Map<String, Object>> findConstructRows(@Param("simulationId") UUID simulationId);
}
