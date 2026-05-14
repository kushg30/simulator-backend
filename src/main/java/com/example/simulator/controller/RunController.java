package com.example.simulator.controller;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import com.example.simulator.service.RunService;
import java.util.Map;
import java.util.UUID;

@RestController
@RequestMapping("/api/runs")
public class RunController {

    private final RunService service;

    public RunController(RunService service) {
        this.service = service;
    }

    // 🔥 START RUN (CEO only)
    @PostMapping("/start/{teamId}")
    public Map<String, Object> startRun(@PathVariable UUID teamId) {
        return service.startRun(teamId);
    }

    // 🔥 GET RUN (used for polling in waiting page)
    @GetMapping("/team/{teamId}")
    public Map<String, Object> getRun(@PathVariable UUID teamId) {
        return service.getRunByTeam(teamId);
    }
}
