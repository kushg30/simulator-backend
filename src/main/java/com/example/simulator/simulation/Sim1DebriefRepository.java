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
			  -- Excluded by run_id (never by name), so a real future team can reuse any of these
			  -- names without being hidden here too. First four are scratch test runs from
			  -- development; the fifth is a duplicate team record from the Sep 12 class session
			  -- (the other "Mockingbirds" entry is kept).
			  AND sr.run_id NOT IN (
			        '10f1ba25-2e1e-468e-9ceb-6994d0924194', -- "Team"
			        'f064d7b8-561c-46db-990c-a1092849325a', -- "Team"
			        'bbd75345-4742-4e7c-8f06-a6d808c157ee', -- "OG Team"
			        '5c1022d5-78e2-4108-87b1-043d2729ce81', -- "OG Team"
			        'a84922a5-43ef-4bd9-990a-345fbaafc0a1'  -- "The Mockingbirds"
			      )
			ORDER BY sr.started_at DESC, sr.run_id, rp.role
			""", nativeQuery = true)
	List<Map<String, Object>> findConstructRows(@Param("simulationId") UUID simulationId);
}
