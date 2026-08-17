package com.example.simulator.faculty;

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

/**
 * Faculty control API — shared by every simulation on the platform.
 *
 * <p>Every route here is behind {@link FacultyAuthFilter}, which requires the shared facilitator
 * token. Scope follows the spec: an action targets either one team (one run) or all teams running a
 * given simulation.
 */
@RestController
@RequestMapping("/api/faculty")
public class FacultyController {

	private final FacultyService service;

	public FacultyController(FacultyService service) {
		this.service = service;
	}

	// --------------------------------------------------------- scope: one team

	@PostMapping("/runs/{runId}/rounds/{roundNumber}/pause")
	public Map<String, Object> pause(@PathVariable UUID runId, @PathVariable int roundNumber,
			@RequestBody(required = false) Map<String, String> body) {
		return service.pause(runId, roundNumber, note(body), actor(body));
	}

	@PostMapping("/runs/{runId}/rounds/{roundNumber}/resume")
	public Map<String, Object> resume(@PathVariable UUID runId, @PathVariable int roundNumber,
			@RequestBody(required = false) Map<String, String> body) {
		return service.resume(runId, roundNumber, note(body), actor(body));
	}

	@GetMapping("/runs/{runId}/rounds/{roundNumber}/clock")
	public Map<String, Object> clock(@PathVariable UUID runId, @PathVariable int roundNumber) {
		return service.status(runId, roundNumber);
	}

	@PostMapping("/runs/{runId}/restart-last-round")
	public ResponseEntity<?> restartLastRound(@PathVariable UUID runId,
			@RequestBody(required = false) Map<String, String> body) {
		try {
			return ResponseEntity.ok(service.restartLastRound(runId, note(body), actor(body)));
		} catch (IllegalStateException e) {
			return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
		}
	}

	@PostMapping("/runs/{runId}/terminate")
	public Map<String, Object> terminate(@PathVariable UUID runId,
			@RequestBody(required = false) Map<String, String> body) {
		return service.terminate(runId, note(body), actor(body));
	}

	// -------------------------------------------------------- scope: all teams

	@PostMapping("/simulations/{simulationId}/pause-all")
	public List<Map<String, Object>> pauseAll(@PathVariable UUID simulationId,
			@RequestBody(required = false) Map<String, String> body) {
		return service.pauseAll(simulationId, true, note(body), actor(body));
	}

	@PostMapping("/simulations/{simulationId}/resume-all")
	public List<Map<String, Object>> resumeAll(@PathVariable UUID simulationId,
			@RequestBody(required = false) Map<String, String> body) {
		return service.pauseAll(simulationId, false, note(body), actor(body));
	}

	// ---------------------------------------------------------------- console

	/** Everything currently in play, for the facilitator console. */
	@GetMapping("/overview")
	public List<Map<String, Object>> overview() {
		return service.sessionOverview();
	}

	/** Artifacts in a round, with any override applied — the targets for delay/bypass. */
	@GetMapping("/runs/{runId}/rounds/{roundNumber}/artifacts")
	public List<Map<String, Object>> roundArtifacts(@PathVariable UUID runId,
			@PathVariable int roundNumber) {
		return service.roundArtifacts(runId, roundNumber);
	}

	// ------------------------------------------------------------------ delay

	@PostMapping("/runs/{runId}/rounds/{roundNumber}/delay")
	public ResponseEntity<?> delay(@PathVariable UUID runId, @PathVariable int roundNumber,
			@RequestBody Map<String, String> body) {
		try {
			return ResponseEntity.ok(service.delay(runId, roundNumber,
					UUID.fromString(body.get("artifactId")),
					Integer.parseInt(body.getOrDefault("minutes", "0")),
					body.get("note"), body.get("actor")));
		} catch (IllegalArgumentException | IllegalStateException e) {
			return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
		}
	}

	// ----------------------------------------------------------------- bypass

	@PostMapping("/runs/{runId}/rounds/{roundNumber}/bypass-artifact")
	public ResponseEntity<?> bypassArtifact(@PathVariable UUID runId, @PathVariable int roundNumber,
			@RequestBody Map<String, String> body) {
		try {
			return ResponseEntity.ok(service.bypassArtifact(runId, roundNumber,
					UUID.fromString(body.get("artifactId")), body.get("note"), body.get("actor")));
		} catch (IllegalArgumentException | IllegalStateException e) {
			return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
		}
	}

	@PostMapping("/runs/{runId}/rounds/{roundNumber}/bypass-round")
	public ResponseEntity<?> bypassRound(@PathVariable UUID runId, @PathVariable int roundNumber,
			@RequestBody(required = false) Map<String, String> body) {
		try {
			return ResponseEntity.ok(service.bypassRound(runId, roundNumber, note(body), actor(body)));
		} catch (IllegalStateException e) {
			return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
		}
	}

	// -------------------------------------------------------------- injection

	@GetMapping("/simulations/{simulationId}/catalogue")
	public List<Map<String, Object>> catalogue(@PathVariable UUID simulationId) {
		return service.catalogue(simulationId);
	}

	@PostMapping("/runs/{runId}/rounds/{roundNumber}/inject")
	public ResponseEntity<?> inject(@PathVariable UUID runId, @PathVariable int roundNumber,
			@RequestBody Map<String, Object> body) {
		try {
			Object catalogueId = body.get("catalogueId");
			return ResponseEntity.ok(service.inject(runId, roundNumber,
					(catalogueId == null || String.valueOf(catalogueId).isBlank())
							? null : UUID.fromString(String.valueOf(catalogueId)),
					(String) body.get("title"),
					(String) body.get("content"),
					Boolean.TRUE.equals(body.get("scored")),
					(String) body.get("canonicalAnswer"),
					(String) body.get("actor")));
		} catch (IllegalArgumentException | IllegalStateException e) {
			return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
		}
	}

	// ------------------------------------------------------------- action log

	@GetMapping("/actions")
	public List<Map<String, Object>> actions(@RequestParam(required = false) UUID runId) {
		return service.actionLog(runId);
	}

	private String note(Map<String, String> body) {
		return body == null ? null : body.get("note");
	}

	private String actor(Map<String, String> body) {
		return body == null ? null : body.get("actor");
	}
}
