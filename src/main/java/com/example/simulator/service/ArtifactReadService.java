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
				repository.findVisibleArtifacts(runId, participantId).stream()
						.map(v -> resolveVariant(toResponse(v), runId, participantId)).toList());

		// Artifacts a facilitator pushed into this run appear to every student as a
		// read-only note in the Inbox, so faculty "insert artifact" actually reaches
		// the team (Simulator 1 has no separate injected-artifact read path otherwise).
		for (Map<String, Object> inj : repository.findInjectedArtifacts(runId)) {
			out.add(injectedToResponse(inj));
		}
		return out;
	}

	/**
	 * Adaptive content (script Rounds 2): an artifact whose payload carries {@code variant_on} swaps a
	 * field (default "body", or "messages") to the entry in {@code variants} keyed by the action taken
	 * on an earlier decision — e.g. the R2 recap tone by the CEO's R1 framing, the investor follow-up by
	 * the R1 investor-draft choice, the engineering-fork thread by the R1 tagging choice. {@code cross_role}
	 * resolves any participant's choice (a CEO framing seen by all); otherwise the viewer's own choice.
	 * If no triggering decision exists yet, the payload's default field is left untouched.
	 */
	@SuppressWarnings("unchecked")
	private VisibleArtifactResponse resolveVariant(VisibleArtifactResponse r, UUID runId, UUID participantId) {
		if (r.payload() == null || !r.payload().contains("variant_on")) {
			return r;
		}
		try {
			Map<String, Object> payload = MAPPER.readValue(r.payload(), Map.class);
			Object vonObj = payload.get("variant_on");
			Object variantsObj = payload.get("variants");
			if (!(vonObj instanceof Map) || !(variantsObj instanceof Map)) {
				return r;
			}
			Map<String, Object> von = (Map<String, Object>) vonObj;
			Map<String, Object> variants = (Map<String, Object>) variantsObj;

			UUID decisionId = UUID.fromString(String.valueOf(von.get("decision_id")));
			boolean crossRole = Boolean.TRUE.equals(von.get("cross_role"));
			String field = von.get("field") == null ? "body" : String.valueOf(von.get("field"));

			String action = repository.findDecisionAction(runId, decisionId, crossRole ? null : participantId);
			if (action == null || !variants.containsKey(action)) {
				return r; // no choice made yet (or no matching variant) — keep the default
			}
			payload.put(field, variants.get(action));
			String newPayload = MAPPER.writeValueAsString(payload);
			return new VisibleArtifactResponse(r.artifactId(), r.artifactType(), newPayload,
					r.expectedAction(), r.roundNumber(), r.decisionId(), r.decisionType(),
					r.decisionOptions(), r.allowedRoles(), r.actionState(), r.openAt(), r.expiresAt(),
					r.chosenAction());
		} catch (Exception e) {
			return r; // never let a malformed variant hide an artifact
		}
	}

	/**
	 * The run's current round for the round screen: its number, start time and the total round
	 * count — or {@code completed:true} once the final round's decision has been submitted.
	 */
	@Transactional(readOnly = true)
	public Map<String, Object> getRoundState(UUID runId) {
		Map<String, Object> active = repository.findSim1ActiveRound(runId);
		Map<String, Object> out = new LinkedHashMap<>();
		if (active == null || active.isEmpty()) {
			out.put("completed", true);
			return out;
		}
		out.put("completed", false);
		out.put("roundNumber", active.get("roundNumber"));
		out.put("startedAt", active.get("startedAt"));
		out.put("totalRounds", active.get("totalRounds"));
		out.put("durationMinutes", active.get("durationMinutes")); // for the round countdown timer

		int roundNumber = ((Number) active.get("roundNumber")).intValue();
		UUID runId2 = runId;

		// Pause-aware countdown (1.2 News + faculty pause): the client subtracts this so the timer
		// freezes while the schedule is held, instead of ticking through a pause.
		Integer paused = repository.findPausedSeconds(runId2, roundNumber);
		out.put("pausedSeconds", paused == null ? 0 : paused);

		// A live News interrupt (1.2) — full-screen to every role, no Inbox entry.
		Map<String, Object> news = repository.findActiveNews(runId2, roundNumber);
		out.put("news", news == null || news.isEmpty() ? null : news);
		return out;
	}

	/**
	 * Post-round interstitial data (1.10): the CEO's submitted framing for a completed round, or a
	 * flag that the round timed out with no decision. Title and discussion prompt are client-side
	 * constants sourced from the Faculty Debrief Guide (script Section 8).
	 */
	@Transactional(readOnly = true)
	public Map<String, Object> getRoundSummary(UUID runId, int roundNumber) {
		Map<String, Object> out = new LinkedHashMap<>();
		out.put("roundNumber", roundNumber);
		boolean submitted = repository.countFinalDecision(runId, roundNumber) > 0;
		out.put("submitted", submitted);
		if (submitted) {
			Map<String, Object> f = repository.findFinalFraming(runId, roundNumber);
			Object label = f == null ? null : f.get("label");
			Object action = f == null ? null : f.get("action");
			out.put("framing", label != null ? label : action);
		} else {
			out.put("framing", "No decision submitted");
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
