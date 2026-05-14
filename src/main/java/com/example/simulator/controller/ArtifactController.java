package com.example.simulator.controller;

import java.util.*;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
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

}
