package com.example.simulator.controller;

import java.util.*;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.simulator.dto.VisibleArtifactResponse;
import com.example.simulator.service.ArtifactReadService;

@RestController
@RequestMapping("/api/runs")
public class ArtifactController {

    private final ArtifactReadService service;

    public ArtifactController(ArtifactReadService service) {
        this.service = service;
    }

    @GetMapping("/{runId}/participants/{participantId}/artifacts")
    public List<VisibleArtifactResponse> getArtifacts(
            @PathVariable UUID runId,
            @PathVariable UUID participantId) {

        return service.getVisibleArtifacts(runId, participantId);
    }

    /** Current round of a run (number, start time, total) or completed — for the round screen. */
    @GetMapping("/{runId}/round-state")
    public Map<String, Object> roundState(@PathVariable UUID runId) {
        return service.getRoundState(runId);
    }

    /** Post-round interstitial (1.10): the CEO's framing for a completed round, or a timeout flag. */
    @GetMapping("/{runId}/rounds/{roundNumber}/summary")
    public Map<String, Object> roundSummary(@PathVariable UUID runId, @PathVariable int roundNumber) {
        return service.getRoundSummary(runId, roundNumber);
    }

    /** End-of-simulation qualitative reveal for participants: four variables as High/Medium/Low (7). */
    @GetMapping("/{runId}/reveal")
    public Map<String, Object> reveal(@PathVariable UUID runId) {
        return service.getReveal(runId);
    }

    /** CEO releases a completed round's debrief interstitial so the team advances together. */
    @PostMapping("/{runId}/rounds/{roundNumber}/ack-interstitial")
    public ResponseEntity<?> ackInterstitial(@PathVariable UUID runId, @PathVariable int roundNumber,
            @RequestBody Map<String, String> body) {
        try {
            service.ackInterstitial(runId, roundNumber, UUID.fromString(body.get("participantId")));
            return ResponseEntity.ok(Map.of("acked", true));
        } catch (IllegalStateException | IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

}
