package com.example.simulator.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.simulator.entity.Team;

@Repository
public interface TeamRepository extends JpaRepository<Team, UUID> {

	/** How many still-live teams (no terminated run) currently use this join code. */
	@Query(value = """
			SELECT count(*) FROM team t
			WHERE t.join_code = :code
			  AND NOT EXISTS (SELECT 1 FROM simulation_runs sr
			                   WHERE sr.team_id = t.team_id AND sr.status = 'TERMINATED')
			""", nativeQuery = true)
	long countLiveByJoinCode(@Param("code") String code);

	/** The team id for a live team with this join code, or null. */
	@Query(value = """
			SELECT t.team_id FROM team t
			WHERE t.join_code = :code
			  AND NOT EXISTS (SELECT 1 FROM simulation_runs sr
			                   WHERE sr.team_id = t.team_id AND sr.status = 'TERMINATED')
			LIMIT 1
			""", nativeQuery = true)
	UUID resolveLiveTeamByCode(@Param("code") String code);
}
