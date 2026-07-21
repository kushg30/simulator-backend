package com.example.simulator.faculty;

import java.util.List;
import java.util.Map;
import java.util.UUID;

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
