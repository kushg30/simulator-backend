package com.example.simulator.sim1;

import java.util.Map;
import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Faculty-only Set-B construct readout for Simulator 1. Mapped under {@code /api/faculty/**} so it inherits
 * the facilitator-token gate — students never see these numbers. Kept separate from the existing
 * {@code com.example.simulator.simulation.Sim1DebriefController} (which serves the Set-A debrief); this one
 * only adds the per-run construct endpoint, so the class name must differ to avoid a bean collision.
 */
@RestController
@RequestMapping("/api/faculty/sim1")
public class Sim1ConstructController {

    private final Sim1ConstructService service;

    public Sim1ConstructController(Sim1ConstructService service) {
        this.service = service;
    }

    /** The five constructs per participant and for the team (values + Low/Med/High bands). */
    @GetMapping("/runs/{runId}/constructs")
    public Map<String, Object> constructs(@PathVariable UUID runId) {
        return service.constructs(runId);
    }

    /** Every played team for a simulation, plus class-level insight statements. */
    @GetMapping("/simulations/{simulationId}/constructs")
    public Map<String, Object> cohort(@PathVariable UUID simulationId) {
        return service.cohort(simulationId);
    }
}
