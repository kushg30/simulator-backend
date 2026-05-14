package com.example.simulator.controller;

import java.util.Map;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.simulator.dto.RecordDecisionRequest;
import com.example.simulator.repository.ArtifactQueryRepository;
import com.example.simulator.service.DecisionWriteService;

@RestController
@RequestMapping("/api/runs")
public class DecisionController {

    private final DecisionWriteService service;
    private final ArtifactQueryRepository repository;

    public DecisionController(DecisionWriteService service,ArtifactQueryRepository repository) {
        this.service = service;
        this.repository = repository;
    }

    @PostMapping("/{runId}/decisions")
    public ResponseEntity<?> recordDecision(
        @PathVariable UUID runId,
        @RequestBody RecordDecisionRequest request
    ) {
        try {
            service.recordDecision(runId, request);
            return ResponseEntity.ok().build();
        } catch (IllegalStateException e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }
    
    @GetMapping("/{runId}/participants/{participantId}/results")
    public ResponseEntity<?> getParticipantResults(
        @PathVariable UUID runId,
        @PathVariable UUID participantId
    ) {
        return ResponseEntity.ok(repository.getParticipantResults(runId, participantId));
    }
    
    @GetMapping("/{runId}/team-results")
    public ResponseEntity<?> getTeamResults(@PathVariable UUID runId) {
        return ResponseEntity.ok(repository.getTeamResults(runId));
    }
    
}
