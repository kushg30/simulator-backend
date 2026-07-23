package com.example.simulator.sim2;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * Reference wiki (spec 9F).
 *
 * <p>The read endpoint is student-facing and unauthenticated: it is self-serve reference, always
 * available, and reveals no answers. The FAQ write endpoints are faculty-only and live under
 * {@code /api/faculty}, so they sit behind the facilitator token guard.
 */
@RestController
public class Sim2WikiController {

	private final Sim2WikiRepository repository;

	public Sim2WikiController(Sim2WikiRepository repository) {
		this.repository = repository;
	}

	/** Student view: functions for the current round (0 = all) plus all facts and FAQ. */
	@GetMapping("/api/sim2/runs/{runId}/wiki")
	public List<Map<String, Object>> wikiForRun(@PathVariable UUID runId,
			@RequestParam(defaultValue = "0") int round) {
		UUID simulationId = repository.findSimulationId(runId);
		if (simulationId == null) {
			return List.of();
		}
		return repository.findEntries(simulationId, round);
	}

	// --------------------------------------------------------- faculty FAQ CRUD

	@GetMapping("/api/faculty/sim2/simulations/{simulationId}/wiki")
	public List<Map<String, Object>> wikiForSimulation(@PathVariable UUID simulationId) {
		return repository.findEntries(simulationId, 0);
	}

	@PostMapping("/api/faculty/sim2/simulations/{simulationId}/faq")
	@Transactional
	public ResponseEntity<?> addFaq(@PathVariable UUID simulationId,
			@RequestBody Map<String, String> body) {
		String title = body.get("title");
		String text = body.get("body");
		if (title == null || title.isBlank() || text == null || text.isBlank()) {
			return ResponseEntity.badRequest().body(Map.of("error", "title and body are required"));
		}
		repository.addFaq(simulationId, title.trim(), text.trim());
		return ResponseEntity.ok(Map.of("added", true));
	}

	@PutMapping("/api/faculty/sim2/faq/{entryId}")
	@Transactional
	public ResponseEntity<?> editFaq(@PathVariable UUID entryId, @RequestBody Map<String, String> body) {
		int n = repository.editFaq(entryId, body.getOrDefault("title", "").trim(),
				body.getOrDefault("body", "").trim());
		if (n == 0) {
			return ResponseEntity.badRequest().body(Map.of("error", "No editable FAQ entry with that id"));
		}
		return ResponseEntity.ok(Map.of("updated", true));
	}

	@DeleteMapping("/api/faculty/sim2/faq/{entryId}")
	@Transactional
	public ResponseEntity<?> deleteFaq(@PathVariable UUID entryId) {
		int n = repository.deleteFaq(entryId);
		if (n == 0) {
			return ResponseEntity.badRequest().body(Map.of("error", "No editable FAQ entry with that id"));
		}
		return ResponseEntity.ok(Map.of("deleted", true));
	}
}
