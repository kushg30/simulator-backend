package com.example.simulator.faculty;

import java.util.LinkedHashMap;
import java.util.Map;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.simulator.config.Validate;

/**
 * The one cohort route students reach, and the only one outside the facilitator token.
 *
 * <p>Sits under {@code /api/cohorts} rather than {@code /api/faculty} precisely so the auth filter
 * does <em>not</em> cover it: a student has no credential, only the code their facilitator read out.
 *
 * <p>What it returns is deliberately thin — the batch's id, name and simulation, and nothing else.
 * It does not name the institution. A student does not need it, and an endpoint anybody can call
 * should not become a way to enumerate which colleges are customers.
 */
@RestController
@RequestMapping("/api/cohorts")
public class CohortAccessController {

	/** Matches the generated alphabet: no I, O, 0 or 1, because these are read aloud and retyped. */
	private static final String CODE_PATTERN = "[A-HJ-NP-Za-hj-np-z2-9]{4,12}";

	private final CohortAccessRepository repo;

	public CohortAccessController(CohortAccessRepository repo) {
		this.repo = repo;
	}

	/**
	 * Resolve a batch code a student typed.
	 *
	 * <p>A closed batch and a code that never existed both come back as the same refusal. Telling
	 * the caller which one it was would turn this into a way to discover valid codes.
	 */
	@GetMapping("/resolve/{code}")
	public Map<String, Object> resolve(@PathVariable String code) {
		String clean = Validate.matching(code, "Batch code", CODE_PATTERN, 12,
				"should be the code your facilitator gave you");

		Map<String, Object> row = repo.findActiveByJoinCode(clean);
		if (row == null || row.isEmpty()) {
			throw new IllegalArgumentException(
					"That batch code was not recognised. Check it with your facilitator.");
		}

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("cohortId", row.get("cohortId"));
		out.put("cohortName", row.get("cohortName"));
		out.put("simulationId", row.get("simulationId"));
		return out;
	}
}
