package com.example.simulator.sim1;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.simulator.simulation.SimulationRun;

/**
 * Set-B (Leadership Judgment) construct queries for Simulator 1.
 *
 * <p>The five canonical constructs are computed from each participant's recorded decisions, weighted by
 * where the artifact opened in the round (early decisions count more, per the spec's sequence sensitivity).
 */
@Repository
public interface Sim1ConstructRepository
        extends org.springframework.data.repository.Repository<SimulationRun, UUID> {

    /**
     * Per participant and construct, the summed weighted delta for a run.
     * Weight by artifact open time: T+0-10 = 1.5x, T+11-20 = 1.0x, T+21-30 = 0.7x.
     */
    @Query(value = """
            SELECT de.run_participant_id AS "participantId",
                   oc.construct_name      AS "construct",
                   SUM(oc.base_delta * CASE WHEN a.open_offset_min <= 10 THEN 1.5
                                            WHEN a.open_offset_min <= 20 THEN 1.0
                                            ELSE 0.7 END) AS "weighted"
            FROM decision_events de
            JOIN decision_options o         ON o.decision_id = de.decision_id AND o.action = de.action
            JOIN sim1_option_constructs oc  ON oc.option_id = o.option_id
            JOIN artifacts a                ON a.artifact_id = de.artifact_id
            WHERE de.run_id = :runId
            GROUP BY de.run_participant_id, oc.construct_name
            """, nativeQuery = true)
    List<Map<String, Object>> findConstructDeltas(@Param("runId") UUID runId);

    /** Every participant in the run with their role and name (so roles that never acted still appear). */
    @Query(value = """
            SELECT rp.run_participant_id AS "participantId", rp.role AS "role", p.name AS "name"
            FROM run_participants rp
            LEFT JOIN participant p ON p.participant_id = rp.run_participant_id
            WHERE rp.run_id = :runId
            ORDER BY rp.role
            """, nativeQuery = true)
    List<Map<String, Object>> findRunParticipants(@Param("runId") UUID runId);

    @Query(value = """
            SELECT t.team_name
            FROM simulation_runs sr
            JOIN team t ON t.team_id = sr.team_id
            WHERE sr.run_id = :runId
            """, nativeQuery = true)
    String findTeamName(@Param("runId") UUID runId);
}
