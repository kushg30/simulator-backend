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
	private final Sim2DebriefService debrief;
	private final Sim2Repository sim2Repository;
	private final Sim2ScoringService scoring;

	public Sim2EngagementController(Sim2EngagementRepository repository, Sim2DebriefService debrief,
			Sim2Repository sim2Repository, Sim2ScoringService scoring) {
		this.repository = repository;
		this.debrief = debrief;
		this.sim2Repository = sim2Repository;
		this.scoring = scoring;
	}

	/** Partial Leaderboard reveal (Data Trust + Turnaround only) shown between Rounds 2 and 3. */
	@GetMapping("/simulations/{simulationId}/partial-leaderboard")
	public Map<String, Object> partialLeaderboard(@PathVariable UUID simulationId) {
		return debrief.partialLeaderboard(simulationId);
	}

	/** Latest broadcast for a simulation; clients show it once (tracked client-side by id). */
	@GetMapping("/simulations/{simulationId}/broadcast")
	public Map<String, Object> latestBroadcast(@PathVariable UUID simulationId) {
		Map<String, Object> b = repository.findLatestBroadcast(simulationId);
		return b == null ? Map.of() : b;
	}

	// v3 Breaking News variants (from the video brief), tied to the team's R2 answer.
	private static final String BREAKING_TRAINING =
			"Quick update — I just got budget approval to fund additional manager training for the West "
					+ "region, based on what you flagged. That's moving forward. Keep going.";
	private static final String BREAKING_MARKET =
			"Heads up — one of our board members just pushed back on the market explanation for West's "
					+ "numbers. She wants to know why training hours weren't considered. Worth keeping in mind.";

	/**
	 * Run-scoped broadcast: the same trigger, but the Breaking News message is personalised to the
	 * team's Round 2 root-cause answer (v5: People/Process/Market/Resource). A team on the People /
	 * training cause hears the training budget was approved; a team that answered Market hears a board
	 * member push back. Process / Resource / unknown fall back to the training variant (per the video
	 * brief's "ship Variant A to everyone" fallback).
	 */
	@GetMapping("/runs/{runId}/broadcast")
	public Map<String, Object> runBroadcast(@PathVariable UUID runId) {
		// Only broadcasts sent AFTER this run started — a leftover broadcast never
		// fires for a team that started later.
		Map<String, Object> b = repository.findLatestBroadcastForRun(runId);
		if (b == null || b.isEmpty()) {
			return Map.of();
		}
		String r2 = repository.findRound2Answer(runId);
		String lower = r2 == null ? "" : r2.toLowerCase();
		boolean market = lower.contains("market") && !lower.contains("training");
		java.util.Map<String, Object> out = new java.util.LinkedHashMap<>(b);
		out.put("message", market ? BREAKING_MARKET : BREAKING_TRAINING);
		return out;
	}

	/**
	 * v6 Breaking-News confidence revision: the team revises its stated Round 2 confidence before it
	 * locks. Records the revised value and re-scores Round 2 Judgment Calibration with the modifier.
	 */
	@PostMapping("/runs/{runId}/rounds/2/revise-confidence")
	@Transactional
	public ResponseEntity<?> reviseConfidence(@PathVariable UUID runId, @RequestBody Map<String, Object> body) {
		String conf = body.get("confidence") == null ? "" : String.valueOf(body.get("confidence")).trim().toUpperCase();
		if (!conf.equals("HIGH") && !conf.equals("MEDIUM") && !conf.equals("LOW")) {
			return ResponseEntity.badRequest().body(Map.of("error", "confidence must be HIGH, MEDIUM or LOW"));
		}
		if (sim2Repository.findSubmission(runId, 2) == null) {
			return ResponseEntity.badRequest().body(Map.of("error", "Round 2 has not been submitted yet"));
		}
		sim2Repository.updateRevisedConfidence(runId, 2, conf);
		scoring.rescoreRound2WithRevision(runId);
		return ResponseEntity.ok(Map.of("runId", runId, "roundNumber", 2, "revisedConfidence", conf));
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
