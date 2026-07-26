package com.example.simulator.simulation;

import java.util.Map;
import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Faculty-facing debrief for Simulator 1.
 *
 * <p>Mounted under {@code /api/faculty} so it sits behind the facilitator token guard, matching
 * {@code Sim2DebriefController}. Simulator 1's results are faculty-only: students are shown no
 * scores, the facilitator reveals them qualitatively at the end.
 */
@RestController
@RequestMapping("/api/faculty/sim1")
public class Sim1DebriefController {

	private final Sim1DebriefService debrief;

	public Sim1DebriefController(Sim1DebriefService debrief) {
		this.debrief = debrief;
	}

	/** Every Simulator 1 team for a simulation, with role-level and team-level construct values. */
	@GetMapping("/simulations/{simulationId}/debrief")
	public Map<String, Object> debrief(@PathVariable UUID simulationId) {
		return debrief.debrief(simulationId);
	}
}
