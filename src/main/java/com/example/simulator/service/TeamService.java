package com.example.simulator.service;

import java.util.*;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.example.simulator.entity.Participant;
import com.example.simulator.entity.Team;
import com.example.simulator.repository.ParticipantRepository;
import com.example.simulator.repository.SimulationRoleRepository;
import com.example.simulator.repository.TeamRepository;

@Service
public class TeamService {

    private final TeamRepository teamRepo;
    private final ParticipantRepository participantRepo;
    private final SimulationRoleRepository simulationRoleRepo;

    /** Simulation used when a caller does not specify one (Simulation 1). */
    private final UUID defaultSimulationId;

    public TeamService(TeamRepository teamRepo,
                       ParticipantRepository participantRepo,
                       SimulationRoleRepository simulationRoleRepo,
                       @Value("${simulator.default-simulation-id:475db739-0708-48d4-b4db-5a23f1da50d9}") String defaultSimulationId) {
        this.teamRepo = teamRepo;
        this.participantRepo = participantRepo;
        this.simulationRoleRepo = simulationRoleRepo;
        this.defaultSimulationId = UUID.fromString(defaultSimulationId);
    }

    /**
     * Resolves which simulation a team is playing. Teams created before multi-simulation
     * support have no simulation_id and are treated as Simulation 1.
     */
    public UUID resolveSimulationId(UUID teamId) {
        UUID sim = teamRepo.findById(teamId).map(Team::getSimulationId).orElse(null);
        return (sim != null) ? sim : defaultSimulationId;
    }

    // 🔵 CREATE TEAM (creator becomes the simulation's lead role)
    public Map<String, Object> createTeam(String teamName, String participantName, UUID simulationId) {

        // Team name must not be blank or all digits (would clash with the numeric join code).
        String name = teamName == null ? "" : teamName.trim();
        if (name.isEmpty()) {
            throw new RuntimeException("Team name is required");
        }
        if (name.matches("\\d+")) {
            throw new RuntimeException("Team name can't be only numbers — add a letter or word");
        }

        UUID sim = (simulationId != null) ? simulationId : defaultSimulationId;

        String leadRole = simulationRoleRepo.findLeadRoleCode(sim);
        if (leadRole == null) {
            throw new IllegalStateException("Simulation " + sim + " has no lead role configured");
        }

        Team team = new Team();
        team.setTeamName(name);
        team.setSimulationId(sim);
        team.setJoinCode(generateJoinCode());
        teamRepo.save(team);

        Participant participant = new Participant();
        participant.setTeamId(team.getTeamId());
        participant.setName(participantName);
        participant.setRole(leadRole); // first user = lead (CEO for Sim 1, TEAM_LEAD for Sim 2)
        participantRepo.save(participant);

        Map<String, Object> response = new HashMap<>();
        response.put("teamId", team.getTeamId());
        response.put("participantId", participant.getParticipantId());
        response.put("role", leadRole);
        response.put("joinCode", team.getJoinCode());
        response.put("simulationId", sim);

        return response;
    }

    /** A short 4-digit code, unique among still-live teams, for students to type when joining. */
    private String generateJoinCode() {
        for (int attempt = 0; attempt < 50; attempt++) {
            String code = String.valueOf(1000 + java.util.concurrent.ThreadLocalRandom.current().nextInt(9000));
            if (teamRepo.countLiveByJoinCode(code) == 0) {
                return code;
            }
        }
        // Extremely unlikely fallback: 5 digits.
        return String.valueOf(10000 + java.util.concurrent.ThreadLocalRandom.current().nextInt(90000));
    }

    /** Basic team info (name + join code) for display on the role / round screens. */
    public Map<String, Object> getTeamInfo(UUID teamId) {
        Team team = teamRepo.findById(teamId).orElseThrow(() -> new RuntimeException("Team not found"));
        Map<String, Object> info = new HashMap<>();
        info.put("teamId", team.getTeamId());
        info.put("teamName", team.getTeamName());
        info.put("joinCode", team.getJoinCode());
        return info;
    }

    /** Resolve a join code to the live team's id. Throws if no live team uses that code. */
    public Map<String, Object> resolveCode(String code) {
        UUID teamId = teamRepo.resolveLiveTeamByCode(code == null ? "" : code.trim());
        if (teamId == null) {
            throw new RuntimeException("No active team found for code " + code);
        }
        return Map.of("teamId", teamId);
    }

    // 🟢 JOIN TEAM
    public Map<String, Object> joinTeam(UUID teamId, String participantName) {

        Participant participant = new Participant();
        participant.setTeamId(teamId);
        participant.setName(participantName);
        participant.setRole(null);
        participantRepo.save(participant);

        Map<String, Object> response = new HashMap<>();
        response.put("participantId", participant.getParticipantId());

        return response;
    }

    /**
     * Role -> occupant map for the team's simulation. Unoccupied roles map to null, which is
     * what the role-selection screen uses to grey out taken roles.
     */
    public Map<String, String> getRoles(UUID teamId) {

        List<String> allRoles = simulationRoleRepo.findRoleCodes(resolveSimulationId(teamId));

        Map<String, String> roles = new LinkedHashMap<>();

        // initialize all roles as FREE
        for (String role : allRoles) {
            roles.put(role, null);
        }

        List<Participant> participants = participantRepo.findByTeamId(teamId);

        for (Participant p : participants) {
            if (p.getRole() != null) {
                roles.put(p.getRole(), p.getParticipantId().toString());
            }
        }

        return roles;
    }

    public void assignRole(UUID teamId, UUID participantId, String role, String name) {

        UUID sim = resolveSimulationId(teamId);

        // ❌ reject roles that do not belong to this team's simulation
        if (simulationRoleRepo.countRole(sim, role) == 0) {
            throw new RuntimeException("Role '" + role + "' is not valid for this simulation");
        }

        List<Participant> participants = participantRepo.findByTeamId(teamId);

        // ❌ check if role already taken
        boolean taken = participants.stream()
            .anyMatch(p -> role.equals(p.getRole()));

        if (taken) {
            throw new RuntimeException("Role already taken");
        }

        Participant participant = participantRepo.findById(participantId)
            .orElseThrow();

        participant.setRole(role);
        // A joiner supplies their name here (they join by code only); set it if provided.
        if (name != null && !name.isBlank()) {
            participant.setName(name.trim());
        }
        participantRepo.save(participant);
    }

    public List<Map<String, Object>> getParticipants(UUID teamId) {

        List<Participant> list = participantRepo.findByTeamId(teamId);

        List<Map<String, Object>> result = new ArrayList<>();

        for (Participant p : list) {
            Map<String, Object> map = new HashMap<>();
            map.put("participantId", p.getParticipantId());
            map.put("name", p.getName());
            map.put("role", p.getRole());
            result.add(map);
        }

        return result;
    }

}
