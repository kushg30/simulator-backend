package com.example.simulator.service;

import java.sql.Timestamp;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.simulator.dto.VisibleArtifactResponse;
import com.example.simulator.projection.VisibleArtifactView;
import com.example.simulator.repository.ArtifactQueryRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service
public class ArtifactReadService {
	private final ArtifactQueryRepository repository;
	private final DecisionWriteService decisionWriteService;
	private static final ObjectMapper MAPPER = new ObjectMapper();

	public ArtifactReadService(ArtifactQueryRepository repository, DecisionWriteService decisionWriteService) {
		this.repository = repository;
		this.decisionWriteService = decisionWriteService;
	}

	@Transactional
	public List<VisibleArtifactResponse> getVisibleArtifacts(UUID runId, UUID participantId) {

		decisionWriteService.processSilence(runId, participantId);

		List<VisibleArtifactResponse> out = new ArrayList<>(
				repository.findVisibleArtifacts(runId, participantId).stream().map(this::toResponse).toList());

		// Artifacts a facilitator pushed into this run appear to every student as a
		// read-only note in the Inbox, so faculty "insert artifact" actually reaches
		// the team (Simulator 1 has no separate injected-artifact read path otherwise).
		for (Map<String, Object> inj : repository.findInjectedArtifacts(runId)) {
			out.add(injectedToResponse(inj));
		}
		return out;
	}

	private VisibleArtifactResponse toResponse(VisibleArtifactView v) {

		// Engine state → UI state normalization
		String uiActionState = "EXPIRED".equals(v.getActionState()) ? "LOCKED" : v.getActionState();

		return new VisibleArtifactResponse(v.getArtifactId(), v.getArtifactType(), v.getPayload(),
				Boolean.TRUE.equals(v.getExpectedAction()), v.getRoundNumber(), v.getDecisionId(), v.getDecisionType(),
				v.getDecisionOptions(), v.getAllowedRoles(), uiActionState, v.getOpenAt(), v.getExpiresAt(),
				v.getChosenAction());
	}

	/** Maps a facilitator-injected row into a read-only Inbox note for the round screen. */
	private VisibleArtifactResponse injectedToResponse(Map<String, Object> inj) {
		String title = (String) inj.get("title");
		String content = (String) inj.get("content");

		Map<String, Object> payloadMap = new LinkedHashMap<>();
		payloadMap.put("tab", "inbox");
		payloadMap.put("title", title == null || title.isBlank() ? "Facilitator update" : title);
		payloadMap.put("body", content == null ? "" : content);
		payloadMap.put("from", "Facilitator");
		payloadMap.put("injected", true);
		String payload;
		try {
			payload = MAPPER.writeValueAsString(payloadMap);
		} catch (Exception e) {
			payload = "{}";
		}

		Object ts = inj.get("injectedAt");
		LocalDateTime openAt = (ts instanceof Timestamp t) ? t.toLocalDateTime()
				: (ts instanceof LocalDateTime l) ? l : LocalDateTime.now();

		UUID id = (UUID) inj.get("injectionId");
		Integer round = inj.get("roundNumber") == null ? 1 : ((Number) inj.get("roundNumber")).intValue();

		return new VisibleArtifactResponse(id, "INTERNAL_NOTE", payload, false, round, null, null, null, null,
				"READ_ONLY", openAt, null, null);
	}

}
