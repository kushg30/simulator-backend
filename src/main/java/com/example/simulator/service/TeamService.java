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
                       @Value("${simulator.default-simulation-id}") String defaultSimulationId) {
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

        UUID sim = (simulationId != null) ? simulationId : defaultSimulationId;

        String leadRole = simulationRoleRepo.findLeadRoleCode(sim);
        if (leadRole == null) {
            throw new IllegalStateException("Simulation " + sim + " has no lead role configured");
        }

        Team team = new Team();
        team.setTeamName(teamName);
        team.setSimulationId(sim);
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
        response.put("simulationId", sim);

        return response;
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

    public void assignRole(UUID teamId, UUID participantId, String role) {

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
