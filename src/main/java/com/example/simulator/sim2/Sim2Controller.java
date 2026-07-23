package com.example.simulator.sim2;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * Simulator-2 (Meridian Retail QBR) API.
 *
 * <p>Mounted under {@code /api/sim2} so it cannot collide with the Simulation-1 endpoints.
 * Note that no endpoint here ever returns the canonical answer — only the question text.
 */
@RestController
@RequestMapping("/api/sim2/runs")
public class Sim2Controller {

	private final Sim2RoundService roundService;
	private final Sim2SubmissionService submissionService;
	private final Sim2Repository repository;

	public Sim2Controller(Sim2RoundService roundService, Sim2SubmissionService submissionService,
			Sim2Repository repository) {
		this.roundService = roundService;
		this.submissionService = submissionService;
		this.repository = repository;
	}

	// ---------------------------------------------------------------- rounds

	@PostMapping("/{runId}/rounds/{roundNumber}/start")
	public ResponseEntity<?> startRound(@PathVariable UUID runId, @PathVariable int roundNumber) {
		try {
			return ResponseEntity.ok(roundService.startRound(runId, roundNumber));
		} catch (IllegalStateException e) {
			return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
		}
	}

	@GetMapping("/{runId}/state")
	public List<Map<String, Object>> getState(@PathVariable UUID runId) {
		return roundService.getRoundStates(runId);
	}

	@GetMapping("/{runId}/rounds/{roundNumber}/participants/{participantId}/artifacts")
	public List<Map<String, Object>> getArtifacts(@PathVariable UUID runId, @PathVariable int roundNumber,
			@PathVariable UUID participantId) {
		return roundService.getVisibleArtifacts(runId, participantId, roundNumber);
	}

	/** The round's submission question. Safe for students — the answer never leaves the server. */
	@GetMapping("/{runId}/rounds/{roundNumber}/question")
	public Map<String, Object> getQuestion(@PathVariable UUID runId, @PathVariable int roundNumber) {
		String question = repository.findQuestion(runId, roundNumber);
		return Map.of("roundNumber", roundNumber, "question", question == null ? "" : question);
	}

	// ------------------------------------------------------------- decisions

	@PostMapping("/{runId}/decisions")
	public ResponseEntity<?> recordDecision(@PathVariable UUID runId, @RequestBody Map<String, String> body) {
		try {
			roundService.recordDecision(runId, UUID.fromString(body.get("participantId")),
					UUID.fromString(body.get("decisionId")), body.get("action"));
			return ResponseEntity.ok(Map.of("recorded", true));
		} catch (IllegalStateException | IllegalArgumentException e) {
			return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
		}
	}

	// ----------------------------------------------------------- submissions

	@PostMapping("/{runId}/rounds/{roundNumber}/submission")
	public ResponseEntity<?> submit(@PathVariable UUID runId, @PathVariable int roundNumber,
			@RequestParam("participantId") UUID participantId,
			@RequestParam("typedAnswer") String typedAnswer,
			@RequestParam("confidence") String confidence,
			@RequestParam(value = "file", required = false) MultipartFile file) {
		try {
			return ResponseEntity.ok(
					submissionService.submit(runId, roundNumber, participantId, typedAnswer, confidence, file));
		} catch (IllegalStateException e) {
			return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
		}
	}

	@GetMapping("/{runId}/rounds/{roundNumber}/results")
	public Map<String, Object> getResults(@PathVariable UUID runId, @PathVariable int roundNumber) {
		return submissionService.getResults(runId, roundNumber);
	}
}
