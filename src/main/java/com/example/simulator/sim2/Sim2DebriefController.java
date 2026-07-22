package com.example.simulator.sim2;

import java.util.Map;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Faculty-facing cohort debrief for Simulator 2.
 *
 * <p>Mounted under {@code /api/faculty} so it is covered by the facilitator token guard: the
 * leaderboard and per-team flags are faculty analytics, not something a student should read for the
 * whole cohort. A student sees only their own standing, which is served from the student results
 * endpoint instead.
 */
@RestController
@RequestMapping("/api/faculty/sim2")
public class Sim2DebriefController {

	private final Sim2DebriefService debrief;

	public Sim2DebriefController(Sim2DebriefService debrief) {
		this.debrief = debrief;
	}

	/** Full debrief for a simulation: every finalised team, its flags, and the leaderboard. */
	@GetMapping("/simulations/{simulationId}/debrief")
	public Map<String, Object> debrief(@PathVariable UUID simulationId) {
		return debrief.debrief(simulationId);
	}

	/** Just the cross-team leaderboard for a simulation. */
	@GetMapping("/simulations/{simulationId}/leaderboard")
	public Map<String, Object> leaderboard(@PathVariable UUID simulationId) {
		return debrief.leaderboard(simulationId);
	}

	/** Override a finalised construct for a team (e.g. after reviewing the workbook). */
	@PostMapping("/runs/{runId}/constructs/{construct}/override")
	public ResponseEntity<?> override(@PathVariable UUID runId, @PathVariable String construct,
			@RequestBody Map<String, Object> body) {
		try {
			Object v = body.get("value");
			if (v == null) {
				return ResponseEntity.badRequest().body(Map.of("error", "value is required"));
			}
			return ResponseEntity.ok(debrief.override(runId, construct,
					((Number) v).intValue(), (String) body.get("actor"), (String) body.get("reason")));
		} catch (IllegalArgumentException | IllegalStateException e) {
			return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
		}
	}

	/** Revert a construct back to its auto-computed score. */
	@PostMapping("/runs/{runId}/constructs/{construct}/revert")
	public ResponseEntity<?> revert(@PathVariable UUID runId, @PathVariable String construct,
			@RequestBody(required = false) Map<String, Object> body) {
		try {
			String actor = body == null ? null : (String) body.get("actor");
			return ResponseEntity.ok(debrief.revert(runId, construct, actor));
		} catch (IllegalArgumentException e) {
			return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
		}
	}
}
