package com.example.simulator.service;

import java.util.*;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import com.example.simulator.entity.Participant;
import com.example.simulator.entity.Team;
import com.example.simulator.repository.ParticipantRepository;
import com.example.simulator.repository.TeamRepository;

@Service
public class TeamService {

    private final TeamRepository teamRepo;
    private final ParticipantRepository participantRepo;

    public TeamService(TeamRepository teamRepo, ParticipantRepository participantRepo) {
        this.teamRepo = teamRepo;
        this.participantRepo = participantRepo;
    }

    // 🔵 CREATE TEAM (CEO)
    public Map<String, Object> createTeam(String teamName, String participantName) {

        Team team = new Team();
        team.setTeamName(teamName);
        teamRepo.save(team);

        Participant participant = new Participant();
        participant.setTeamId(team.getTeamId());
        participant.setName(participantName);
        participant.setRole("CEO"); // first user = CEO
        participantRepo.save(participant);

        Map<String, Object> response = new HashMap<>();
        response.put("teamId", team.getTeamId());
        response.put("participantId", participant.getParticipantId());
        response.put("role", "CEO");

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
    
    public Map<String, String> getRoles(UUID teamId) {

        List<String> allRoles = List.of(
            "CEO", "CFO", "HEAD_OF_ENGINEERING",
            "PRODUCT", "OPERATIONS", "CHRO"
        );

        Map<String, String> roles = new HashMap<>();

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
