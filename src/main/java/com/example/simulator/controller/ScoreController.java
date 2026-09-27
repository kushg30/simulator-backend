package com.example.simulator.controller;

import java.util.Map;
import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.simulator.service.ScoringService;

/**
 * Raw per-participant scores for the four hidden variables.
 *
 * <p>Mapped under {@code /api/faculty} so the facilitator token filter covers it. It previously sat
 * on {@code /api/runs/{runId}/scores} with no authentication at all, which handed any student their
 * own team's hidden scores mid-simulation for the price of one URL — the runId is already in their
 * address bar. No frontend calls this endpoint, so the move is invisible to every screen.
 */
@RestController
@RequestMapping("/api/faculty/runs")
public class ScoreController {

    private final ScoringService scoringService;

    public ScoreController(ScoringService scoringService) {
        this.scoringService = scoringService;
    }

    @GetMapping("/{runId}/scores")
    public Map<UUID, Map<String, Integer>> getScores(
            @PathVariable UUID runId) {

        return scoringService.getScores(runId);
    }
}
