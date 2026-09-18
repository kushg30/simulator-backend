package com.example.simulator.sim1;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.simulator.simulation.SimulationRun;

/**
 * Read side of the end-of-simulation results screen (script section 8).
 *
 * <p>The engine keeps a rolling 0-100 value per participant for live use. The results screen wants
 * something different: the team's RAW POINT TOTAL per variable — the sum of the script's +1/0/-1
 * across every scored decision, by whichever role made it. That is recomputed here from the decision
 * log rather than read from the rolling state, which means it stays correct no matter how many roles
 * touched a given variable, and it can be sliced per round for the trajectory chart.
 *
 * <p>Points are stored multiplied by {@code :scale} (a raw ±1 would never move the 0-100 band), so
 * every sum here is divided back down to the script's own units.
 */
@Repository
public interface Sim1ResultsRepository
		extends org.springframework.data.repository.Repository<SimulationRun, UUID> {

	/**
	 * Raw points per variable per round for one run, ANSWERED decisions only.
	 *
	 * <p>Summed across all six roles, because the script scores each role's own call independently and
	 * then totals them for the team.
	 */
	@Query(value = """
			SELECT r.round_number AS "round",
			       SUM(o.trust_delta)     / :scale AS "trust",
			       SUM(o.risk_delta)      / :scale AS "governance",
			       SUM(o.execution_delta) / :scale AS "rigor",
			       SUM(o.ethics_delta)    / :scale AS "exposure"
			FROM decision_events de
			JOIN decision_options o ON o.decision_id = de.decision_id AND o.action = de.action
			JOIN decisions d        ON d.decision_id = de.decision_id
			JOIN artifacts a        ON a.artifact_id = de.artifact_id
			JOIN rounds r           ON r.round_id = a.round_id
			WHERE de.run_id = :runId
			  AND de.action <> 'SILENCE'
			GROUP BY r.round_number
			ORDER BY r.round_number
			""", nativeQuery = true)
	List<Map<String, Object>> findAnsweredPointsByRound(@Param("runId") UUID runId, @Param("scale") int scale);

	/**
	 * Raw points per round for the decisions that expired unanswered.
	 *
	 * <p>Script 1.7 scores a No Response as the WORST outcome that decision offered, on every variable
	 * that decision's options could have moved — not as a neutral zero. "Worst" is direction-aware:
	 * the lowest available value for Trust, Governance and Rigor, and the HIGHEST for Ethical Exposure,
	 * since that is the one variable where a bigger number is the worse result. (The script's own
	 * wording says "minus 1" throughout, which reads as a slip for Exposure — taken literally it would
	 * reward silence there. The stated intent, "silence is scored as the worst outcome available", is
	 * what is implemented.)
	 */
	@Query(value = """
			SELECT r.round_number AS "round",
			       SUM(w.worst_trust)      / :scale AS "trust",
			       SUM(w.worst_governance) / :scale AS "governance",
			       SUM(w.worst_rigor)      / :scale AS "rigor",
			       SUM(w.worst_exposure)   / :scale AS "exposure"
			FROM decision_events de
			JOIN artifacts a ON a.artifact_id = de.artifact_id
			JOIN rounds r    ON r.round_id = a.round_id
			CROSS JOIN LATERAL (
			  SELECT MIN(o.trust_delta)     AS worst_trust,
			         MIN(o.risk_delta)      AS worst_governance,
			         MIN(o.execution_delta) AS worst_rigor,
			         MAX(o.ethics_delta)    AS worst_exposure
			  FROM decision_options o WHERE o.decision_id = de.decision_id
			) w
			WHERE de.run_id = :runId
			  AND de.action = 'SILENCE'
			GROUP BY r.round_number
			ORDER BY r.round_number
			""", nativeQuery = true)
	List<Map<String, Object>> findSilencePointsByRound(@Param("runId") UUID runId, @Param("scale") int scale);

	/**
	 * The best and worst total each variable can reach in a simulation, used to set the High/Medium/Low
	 * band edges. Script 3.4 is explicit that these come from the authored table rather than a
	 * hardcoded threshold, so that editing the script moves the bands with it.
	 */
	@Query(value = """
			SELECT SUM(b.max_trust)      / :scale AS "maxTrust",
			       SUM(b.min_trust)      / :scale AS "minTrust",
			       SUM(b.max_governance) / :scale AS "maxGovernance",
			       SUM(b.min_governance) / :scale AS "minGovernance",
			       SUM(b.max_rigor)      / :scale AS "maxRigor",
			       SUM(b.min_rigor)      / :scale AS "minRigor",
			       SUM(b.max_exposure)   / :scale AS "maxExposure",
			       SUM(b.min_exposure)   / :scale AS "minExposure"
			FROM decisions d
			JOIN artifacts a ON a.artifact_id = d.artifact_id
			JOIN rounds r    ON r.round_id = a.round_id
			CROSS JOIN LATERAL (
			  SELECT MAX(o.trust_delta) AS max_trust, MIN(o.trust_delta) AS min_trust,
			         MAX(o.risk_delta) AS max_governance, MIN(o.risk_delta) AS min_governance,
			         MAX(o.execution_delta) AS max_rigor, MIN(o.execution_delta) AS min_rigor,
			         MAX(o.ethics_delta) AS max_exposure, MIN(o.ethics_delta) AS min_exposure
			  FROM decision_options o WHERE o.decision_id = d.decision_id
			) b
			WHERE r.simulation_id = :simulationId
			  AND NOT d.is_final
			""", nativeQuery = true)
	Map<String, Object> findPossibleRange(@Param("simulationId") UUID simulationId, @Param("scale") int scale);

	/**
	 * Every run in the cohort with its raw totals, for the composite ranking and the distribution.
	 *
	 * <p>This has to score a run EXACTLY as the two per-team queries above do together: answered
	 * decisions, PLUS the worst-available penalty for every No Response. It once counted answered
	 * decisions only, so a team that let decisions expire saw its own bar contradict its own composite
	 * — one run reported a composite of -27 beside a cohort bar of 4 — and the ranking was computed on
	 * a different basis from the number every team was actually reading.
	 */
	@Query(value = """
			SELECT sr.run_id AS "runId",
			       COALESCE(SUM(p.trust), 0)      / :scale AS "trust",
			       COALESCE(SUM(p.governance), 0) / :scale AS "governance",
			       COALESCE(SUM(p.rigor), 0)      / :scale AS "rigor",
			       COALESCE(SUM(p.exposure), 0)   / :scale AS "exposure"
			FROM simulation_runs sr
			LEFT JOIN decision_events de ON de.run_id = sr.run_id
			LEFT JOIN LATERAL (
			  SELECT CASE WHEN de.action = 'SILENCE' THEN w.worst_trust      ELSE o.trust_delta     END AS trust,
			         CASE WHEN de.action = 'SILENCE' THEN w.worst_governance ELSE o.risk_delta      END AS governance,
			         CASE WHEN de.action = 'SILENCE' THEN w.worst_rigor      ELSE o.execution_delta END AS rigor,
			         CASE WHEN de.action = 'SILENCE' THEN w.worst_exposure   ELSE o.ethics_delta    END AS exposure
			  FROM (SELECT MIN(x.trust_delta)     AS worst_trust,
			               MIN(x.risk_delta)      AS worst_governance,
			               MIN(x.execution_delta) AS worst_rigor,
			               MAX(x.ethics_delta)    AS worst_exposure
			        FROM decision_options x WHERE x.decision_id = de.decision_id) w
			  LEFT JOIN decision_options o
			         ON o.decision_id = de.decision_id AND o.action = de.action
			) p ON true
			WHERE sr.simulation_id = :simulationId
			  AND sr.status <> 'TERMINATED'
			  AND EXISTS (SELECT 1 FROM decision_events x WHERE x.run_id = sr.run_id)
			GROUP BY sr.run_id
			""", nativeQuery = true)
	List<Map<String, Object>> findCohortTotals(@Param("simulationId") UUID simulationId, @Param("scale") int scale);

	/**
	 * The CEO's four round-ending framings, with the 1-based position of the chosen option.
	 *
	 * <p>Framing Commitment (script 3.6) is computed purely from those positions, so the option's
	 * index in the authored list is the value that matters, not its internal code.
	 */
	@Query(value = """
			SELECT r.round_number AS "round",
			       de.action      AS "action",
			       opt.ord        AS "optionNumber",
			       opt.value->>'label' AS "label"
			FROM decision_events de
			JOIN decisions d ON d.decision_id = de.decision_id AND d.is_final
			JOIN artifacts a ON a.artifact_id = de.artifact_id
			JOIN rounds r    ON r.round_id = a.round_id
			LEFT JOIN LATERAL (
			  SELECT o.value, o.ord FROM jsonb_array_elements(d.options) WITH ORDINALITY o(value, ord)
			  WHERE o.value->>'id' = de.action
			) opt ON true
			WHERE de.run_id = :runId
			ORDER BY r.round_number
			""", nativeQuery = true)
	List<Map<String, Object>> findFramings(@Param("runId") UUID runId);
}
