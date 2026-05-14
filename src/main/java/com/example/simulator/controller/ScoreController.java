package com.example.simulator.controller;

import java.util.Map;
import java.util.UUID;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.simulator.service.ScoringService;

@RestController
@RequestMapping("/api/runs")
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
