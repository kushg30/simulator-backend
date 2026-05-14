package com.example.simulator.service;

import java.util.List;
import java.util.UUID;
import org.springframework.stereotype.Service;
import com.example.simulator.dto.VisibleArtifactResponse;
import com.example.simulator.projection.VisibleArtifactView;
import com.example.simulator.repository.ArtifactQueryRepository;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ArtifactReadService {
	private final ArtifactQueryRepository repository;
	private final DecisionWriteService decisionWriteService;

	public ArtifactReadService(ArtifactQueryRepository repository, DecisionWriteService decisionWriteService) {
		this.repository = repository;
		this.decisionWriteService = decisionWriteService;
	}

	@Transactional
	public List<VisibleArtifactResponse> getVisibleArtifacts(UUID runId, UUID participantId) {

		decisionWriteService.processSilence(runId, participantId);

		return repository.findVisibleArtifacts(runId, participantId).stream().map(this::toResponse).toList();
	}

	private VisibleArtifactResponse toResponse(VisibleArtifactView v) {

		// Engine state → UI state normalization
		String uiActionState = "EXPIRED".equals(v.getActionState()) ? "LOCKED" : v.getActionState();

		return new VisibleArtifactResponse(v.getArtifactId(), v.getArtifactType(), v.getPayload(),
				Boolean.TRUE.equals(v.getExpectedAction()), v.getRoundNumber(), v.getDecisionId(), v.getDecisionType(),
				v.getDecisionOptions(), v.getAllowedRoles(), uiActionState, v.getOpenAt(), v.getExpiresAt(),
				v.getChosenAction());
	}

}
