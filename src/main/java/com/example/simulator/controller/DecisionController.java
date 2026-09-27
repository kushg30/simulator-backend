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
@RequestMapping("/api")
public class DecisionController {

    private final DecisionWriteService service;
    private final ArtifactQueryRepository repository;

    public DecisionController(DecisionWriteService service,ArtifactQueryRepository repository) {
        this.service = service;
        this.repository = repository;
    }

    /** Students record their own decisions here — public, and must stay public. */
    @PostMapping("/runs/{runId}/decisions")
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

    // The two readers below return raw run_construct_state values — the four hidden variables the
    // whole design withholds until the facilitator reveals them. They used to sit on /api/runs/**,
    // which is unauthenticated and keyed only by a runId that every student already has in their own
    // URL, so any participant could read their team's live scores mid-round by typing one URL. No
    // frontend has ever called them, so moving them under /api/faculty (covered by the token filter)
    // closes that without changing a single screen.

    @GetMapping("/faculty/runs/{runId}/participants/{participantId}/results")
    public ResponseEntity<?> getParticipantResults(
        @PathVariable UUID runId,
        @PathVariable UUID participantId
    ) {
        return ResponseEntity.ok(repository.getParticipantResults(runId, participantId));
    }

    @GetMapping("/faculty/runs/{runId}/team-results")
    public ResponseEntity<?> getTeamResults(@PathVariable UUID runId) {
        return ResponseEntity.ok(repository.getTeamResults(runId));
    }
    
}
