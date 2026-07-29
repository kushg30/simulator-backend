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
	private final TeamService teamService;

	/** Simulator 2 (Meridian) manages its own round state; other sims use sim1_round_state. */
	private static final UUID MERIDIAN_SIMULATION_ID =
			UUID.fromString("5116d200-0000-4000-a000-000000000002");

	public RunService(ArtifactQueryRepository repository, TeamRepository teamRepo, TeamService teamService) {
		this.repository = repository;
		this.teamRepo = teamRepo;
		this.teamService = teamService;
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

		// Which simulation this team is playing (falls back to Simulation 1 for
		// teams created before multi-simulation support).
		UUID simulationId = teamService.resolveSimulationId(teamId);

		// 🔥 fetch all participants of team
		List<Map<String, Object>> participants = repository.getParticipantsByTeam(teamId);

		boolean allAssigned = !participants.isEmpty()
				&& participants.stream().allMatch(p -> p.get("role") != null);

		if (!allAssigned) {
			throw new RuntimeException("All roles must be assigned before starting");
		}

		repository.createRun(runId, simulationId, team.getTeamName(), teamId);

		for (Map<String, Object> p : participants) {

			UUID participantId = (UUID) p.get("participantId");
			String role = (String) p.get("role");

			// ⚠️ skip if role not assigned
			if (role == null)
				continue;

			repository.addParticipant(runId, participantId, role);
		}

		// Offset-based simulations (Simulation 1) track progress via sim1_round_state so
		// each round gets its own timeline; Sim 2 uses sim2_round_state and is skipped.
		if (!MERIDIAN_SIMULATION_ID.equals(simulationId)) {
			repository.activateSim1Round(runId, 1);
		}

		return Map.of("runId", runId);
	}
}