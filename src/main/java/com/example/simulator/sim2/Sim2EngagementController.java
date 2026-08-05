package com.example.simulator.sim2;

import java.util.Map;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Student-facing Simulator 2 v2 engagement endpoints: poll the latest facilitator
 * broadcast (Breaking News) and record the team's Emergency Board Call response.
 */
@RestController
@RequestMapping("/api/sim2")
public class Sim2EngagementController {

	private final Sim2EngagementRepository repository;

	public Sim2EngagementController(Sim2EngagementRepository repository) {
		this.repository = repository;
	}

	/** Latest broadcast for a simulation; clients show it once (tracked client-side by id). */
	@GetMapping("/simulations/{simulationId}/broadcast")
	public Map<String, Object> latestBroadcast(@PathVariable UUID simulationId) {
		Map<String, Object> b = repository.findLatestBroadcast(simulationId);
		return b == null ? Map.of() : b;
	}

	/** Record the team's one-line Emergency Board Call response (ungraded, one per round). */
	@PostMapping("/runs/{runId}/board-call")
	@Transactional
	public ResponseEntity<?> boardCall(@PathVariable UUID runId, @RequestBody Map<String, Object> body) {
		String response = body.get("response") == null ? "" : String.valueOf(body.get("response")).trim();
		if (response.isEmpty()) {
			return ResponseEntity.badRequest().body(Map.of("error", "response is required"));
		}
		int round = body.get("roundNumber") == null ? 2 : ((Number) body.get("roundNumber")).intValue();
		UUID participantId = body.get("participantId") == null ? null
				: UUID.fromString(String.valueOf(body.get("participantId")));
		repository.upsertBoardCall(runId, round, participantId, response);
		return ResponseEntity.ok(Map.of("runId", runId, "roundNumber", round, "recorded", true));
	}

	/** Whether this team has already answered the board call for a round. */
	@GetMapping("/runs/{runId}/board-call/{roundNumber}")
	public Map<String, Object> boardCallStatus(@PathVariable UUID runId, @PathVariable int roundNumber) {
		Map<String, Object> r = repository.findBoardCall(runId, roundNumber);
		return r == null ? Map.of("answered", false) : Map.of("answered", true, "response", r.get("response"));
	}
}
