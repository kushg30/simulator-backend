package com.example.simulator.repository;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.simulator.entity.Team;

/**
 * Per-simulation role definitions.
 *
 * <p>Replaces the role list that used to be hardcoded in {@code TeamService}, so that a second
 * simulation can define its own roles without touching Simulation 1.
 */
@Repository
public interface SimulationRoleRepository extends org.springframework.data.repository.Repository<Team, UUID> {

	/** Role codes for a simulation, in authoring order. */
	@Query(value = """
			SELECT role_code
			FROM simulation_roles
			WHERE simulation_id = :simulationId
			ORDER BY ordinal
			""", nativeQuery = true)
	List<String> findRoleCodes(@Param("simulationId") UUID simulationId);

	/**
	 * The role the team creator is auto-assigned, and the only role permitted to submit the
	 * final / per-round decision. Sim 1 => CEO, Sim 2 => TEAM_LEAD.
	 */
	@Query(value = """
			SELECT role_code
			FROM simulation_roles
			WHERE simulation_id = :simulationId
			  AND is_lead
			""", nativeQuery = true)
	String findLeadRoleCode(@Param("simulationId") UUID simulationId);

	/** Guards against assigning a role that does not belong to the team's simulation. */
	@Query(value = """
			SELECT count(*)
			FROM simulation_roles
			WHERE simulation_id = :simulationId
			  AND role_code = :roleCode
			""", nativeQuery = true)
	int countRole(@Param("simulationId") UUID simulationId, @Param("roleCode") String roleCode);
}
