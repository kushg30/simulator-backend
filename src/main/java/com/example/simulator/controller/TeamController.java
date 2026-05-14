package com.example.simulator.controller;

import java.util.*;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.simulator.service.TeamService;

@RestController
@RequestMapping("/api/teams")
public class TeamController {

    private final TeamService service;

    public TeamController(TeamService service) {
        this.service = service;
    }

    // 🔵 CREATE TEAM
    @PostMapping
    public Map<String, Object> createTeam(@RequestBody Map<String, String> req) {

        return service.createTeam(
                req.get("teamName"),
                req.get("participantName")
        );
    }

    // 🟢 JOIN TEAM
    @PostMapping("/{teamId}/join")
    public Map<String, Object> joinTeam(
            @PathVariable UUID teamId,
            @RequestBody Map<String, String> req) {

        return service.joinTeam(teamId, req.get("participantName"));
    }
    
    @GetMapping("/{teamId}/roles")
    public Map<String, String> getRoles(@PathVariable UUID teamId) {
        return service.getRoles(teamId);
    }

    @PostMapping("/{teamId}/assign-role")
    public void assignRole(
            @PathVariable UUID teamId,
            @RequestBody Map<String, String> req) {

        service.assignRole(
            teamId,
            UUID.fromString(req.get("participantId")),
            req.get("role")
        );
    }
    
    @GetMapping("/{teamId}/participants")
    public List<Map<String, Object>> getParticipants(@PathVariable UUID teamId) {
        return service.getParticipants(teamId);
    }
}