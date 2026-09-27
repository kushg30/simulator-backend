package com.example.simulator.controller;

import java.util.*;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.simulator.config.Validate;
import com.example.simulator.service.TeamService;

@RestController
@RequestMapping("/api/teams")
public class TeamController {

    private final TeamService service;

    /**
     * Field limits for everything a student types. Generous enough that no real name or team name is
     * ever refused, small enough that the column cannot be used as free storage.
     */
    private static final int NAME_MAX = 80;

    /**
     * Role codes are authored by us, not typed: they are upper-snake constants like
     * {@code HEAD_OF_ENGINEERING}. The value is checked against the simulation's own role list in the
     * service too — this is the cheap shape check before that lookup.
     */
    private static final String ROLE_PATTERN = "[A-Z][A-Z0-9_]{1,39}";

    /** The join code the students type: 4 digits today, with room for 5-6 if the space is widened. */
    private static final String JOIN_CODE_PATTERN = "[0-9]{4,6}";

    public TeamController(TeamService service) {
        this.service = service;
    }

    // 🔵 CREATE TEAM
    // `simulationId` is optional: when omitted the team is assigned to the default
    // simulation (Sim 1), which keeps the existing Sim-1 frontend working unchanged.
    @PostMapping
    public ResponseEntity<?> createTeam(@RequestBody Map<String, String> req) {
        try {
            return ResponseEntity.ok(service.createTeam(
                    Validate.requiredText(req.get("teamName"), "Team name", NAME_MAX),
                    Validate.optionalText(req.get("participantName"), "Your name", NAME_MAX),
                    Validate.optionalUuid(req.get("simulationId"), "simulationId")
            ));
        } catch (RuntimeException e) {
            // Validation errors (e.g. blank / all-numeric team name) → clean 400, not a 500.
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    // 🟢 JOIN TEAM
    // participantName is OPTIONAL by design and must stay that way: Sim 1 and Sim 3 join with an
    // empty body and collect the name later, on the role-selection screen. Requiring it here would
    // break joining for both.
    @PostMapping("/{teamId}/join")
    public Map<String, Object> joinTeam(
            @PathVariable UUID teamId,
            @RequestBody Map<String, String> req) {

        return service.joinTeam(teamId,
                Validate.optionalText(req.get("participantName"), "Your name", NAME_MAX));
    }

    // 🔎 RESOLVE a short join code → team id
    @GetMapping("/resolve/{code}")
    public Map<String, Object> resolveCode(@PathVariable String code) {
        return service.resolveCode(Validate.matching(
                code, "Join code", JOIN_CODE_PATTERN, 6, "must be the 4-digit code from your CEO"));
    }

    // ℹ️ Team info (name + join code) for display on the role / round screens
    @GetMapping("/{teamId}")
    public Map<String, Object> getTeam(@PathVariable UUID teamId) {
        return service.getTeamInfo(teamId);
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
            Validate.uuid(req.get("participantId"), "participantId"),
            Validate.matching(req.get("role"), "Role", ROLE_PATTERN, 40, "is not a valid role"),
            // Optional: Sim 2 assigns a role without a name (the name was given when joining).
            Validate.optionalText(req.get("name"), "Your name", NAME_MAX)
        );
    }
    
    @GetMapping("/{teamId}/participants")
    public List<Map<String, Object>> getParticipants(@PathVariable UUID teamId) {
        return service.getParticipants(teamId);
    }
}