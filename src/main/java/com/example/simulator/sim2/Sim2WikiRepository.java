package com.example.simulator.sim2;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.simulator.simulation.SimulationRun;

/** Reference wiki (spec 9F): function quick-reference, company facts, faculty FAQ. */
@Repository
public interface Sim2WikiRepository extends org.springframework.data.repository.Repository<SimulationRun, UUID> {

	/** The simulation a run belongs to. */
	@Query(value = "SELECT simulation_id FROM simulation_runs WHERE run_id = :runId", nativeQuery = true)
	UUID findSimulationId(@Param("runId") UUID runId);

	/**
	 * Wiki entries for a simulation. The FUNCTIONS section is scoped: only the card for the given
	 * round is returned (a round shows its own skill anchor, not every round's). FACTS and FAQ are
	 * always returned. Passing round = 0 returns all FUNCTIONS cards (used by the faculty view).
	 */
	@Query(value = """
			SELECT entry_id AS "entryId", section AS "section", round_number AS "roundNumber",
			       title AS "title", body AS "body", editable AS "editable", ordinal AS "ordinal"
			FROM sim2_wiki_entries
			WHERE simulation_id = :simulationId
			  AND (section <> 'FUNCTIONS' OR :round = 0 OR round_number = :round)
			ORDER BY section, round_number NULLS FIRST, ordinal, title
			""", nativeQuery = true)
	List<Map<String, Object>> findEntries(@Param("simulationId") UUID simulationId,
			@Param("round") int round);

	@Modifying
	@Query(value = """
			INSERT INTO sim2_wiki_entries (simulation_id, section, title, body, editable, ordinal)
			VALUES (:simulationId, 'FAQ', :title, :body, true,
			        COALESCE((SELECT MAX(ordinal) + 1 FROM sim2_wiki_entries
			                   WHERE simulation_id = :simulationId AND section = 'FAQ'), 0))
			""", nativeQuery = true)
	void addFaq(@Param("simulationId") UUID simulationId, @Param("title") String title,
			@Param("body") String body);

	/** Edits an FAQ entry. Restricted to editable rows so seeded reference cannot be altered. */
	@Modifying
	@Query(value = """
			UPDATE sim2_wiki_entries SET title = :title, body = :body, updated_at = now()
			WHERE entry_id = :entryId AND editable = true
			""", nativeQuery = true)
	int editFaq(@Param("entryId") UUID entryId, @Param("title") String title,
			@Param("body") String body);

	@Modifying
	@Query(value = "DELETE FROM sim2_wiki_entries WHERE entry_id = :entryId AND editable = true",
			nativeQuery = true)
	int deleteFaq(@Param("entryId") UUID entryId);
}
