package com.example.simulator.service;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.simulator.entity.Team;
import com.example.simulator.repository.ArtifactQueryRepository;
import com.example.simulator.repository.TeamRepository;

@Service
@Transactional
public class RunService {

	private final ArtifactQueryRepository repository;
	private final TeamRepository teamRepo;

	public RunService(ArtifactQueryRepository repository, TeamRepository teamRepo) {
		this.repository = repository;
		this.teamRepo = teamRepo;
	}

	public Map<String, Object> getRunByTeam(UUID teamId) {
		return repository.getRunByTeam(teamId);
	}

	public Map<String, Object> startRun(UUID teamId) {

		Map<String, Object> existing = getRunByTeam(teamId);

		if (existing != null && !existing.isEmpty()) {
			return existing;
		}

		UUID runId = UUID.randomUUID();

		// fetch team
		Team team = teamRepo.findById(teamId).orElseThrow();

		repository.createRun(runId, UUID.fromString("475db739-0708-48d4-b4db-5a23f1da50d9"), team.getTeamName(),
				teamId);

		// 🔥 fetch all participants of team
		List<Map<String, Object>> participants = repository.getParticipantsByTeam(teamId);

		boolean allAssigned = participants.stream().allMatch(p -> p.get("role") != null);

		if (!allAssigned) {
			throw new RuntimeException("All roles must be assigned before starting");
		}

		for (Map<String, Object> p : participants) {

			UUID participantId = (UUID) p.get("participantId");
			String role = (String) p.get("role");

			// ⚠️ skip if role not assigned
			if (role == null)
				continue;

			repository.addParticipant(runId, participantId, role);
		}

		return Map.of("runId", runId);
	}
}