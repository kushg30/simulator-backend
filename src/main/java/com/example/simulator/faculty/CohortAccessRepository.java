package com.example.simulator.faculty;

import java.util.Map;
import java.util.UUID;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.simulator.simulation.SimulationRun;

/**
 * The two cohort lookups the student-facing side needs.
 *
 * <p>Separate from {@link FacultyIdentityRepository} because these are reachable without a
 * facilitator credential, and that boundary is worth being able to see in the file list.
 */
@Repository
public interface CohortAccessRepository
        extends org.springframework.data.repository.Repository<SimulationRun, UUID> {

    /**
     * An ACTIVE batch matching the code, case-insensitively.
     *
     * <p>Closed batches are excluded here rather than filtered afterwards, so a retired code is
     * indistinguishable from one that never existed.
     */
    @Query(value = """
            SELECT c.cohort_id     AS "cohortId",
                   c.name          AS "cohortName",
                   c.simulation_id AS "simulationId"
            FROM cohort c
            WHERE upper(c.join_code) = upper(:code)
              AND c.status = 'ACTIVE'
            """, nativeQuery = true)
    Map<String, Object> findActiveByJoinCode(@Param("code") String code);

    /**
     * The simulation an ACTIVE batch belongs to, or null.
     *
     * <p>Used when a team is created, to refuse a batch code that belongs to a different simulation
     * than the one being played — otherwise a licence for one simulation would open another.
     */
    @Query(value = """
            SELECT c.simulation_id
            FROM cohort c
            WHERE c.cohort_id = :cohortId AND c.status = 'ACTIVE'
            """, nativeQuery = true)
    UUID findActiveSimulationId(@Param("cohortId") UUID cohortId);
}
