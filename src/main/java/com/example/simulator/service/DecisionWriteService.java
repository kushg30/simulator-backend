package com.example.simulator.service;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.simulator.dto.RecordDecisionRequest;
import com.example.simulator.repository.ArtifactQueryRepository;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;

@Service
@Transactional
public class DecisionWriteService {

    private final ArtifactQueryRepository repository;
    private final ObjectMapper objectMapper;

    /** How often, per participant, the expiry sweep is allowed to run. */
    private static final long SILENCE_SWEEP_INTERVAL_MS = 15_000L;
    private final java.util.concurrent.ConcurrentHashMap<UUID, Long> lastSilenceSweep =
            new java.util.concurrent.ConcurrentHashMap<>();

    // Inject ObjectMapper as a Spring bean — no manual instantiation needed
    public DecisionWriteService(ArtifactQueryRepository repository, ObjectMapper objectMapper) {
        this.repository = repository;
        this.objectMapper = objectMapper;
    }

    public void recordDecision(UUID runId, RecordDecisionRequest request) {

        // ── 1. Participant validation ─────────────────────────────────────────
        String role = repository.findParticipantRole(runId, request.participantId());
        if (role == null) {
            throw new IllegalStateException("Participant not part of run");
        }

        // ── 2. Decision metadata ──────────────────────────────────────────────
        var meta = repository.findDecisionMeta(request.decisionId());
        if (meta == null) {
            throw new IllegalStateException("Invalid decision");
        }

        // ── 3. Role check (proper JSON parse, supports ALL) ───────────────────
        if (meta.getAllowedRoles() != null) {
            try {
                List<String> allowedRoles = objectMapper.readValue(
                    meta.getAllowedRoles(),
                    new TypeReference<List<String>>() {}
                );
                if (!allowedRoles.contains("ALL") && !allowedRoles.contains(role)) {
                    throw new IllegalStateException("Role not allowed to take this decision");
                }
            } catch (IllegalStateException e) {
                throw e;
            } catch (Exception e) {
                throw new IllegalStateException("Invalid allowed_roles format");
            }
        }

        // ── 4. Final decision enforcement ─────────────────────────────────────
        if (Boolean.TRUE.equals(meta.getIsFinal()) && !"CEO".equals(role)) {
            throw new IllegalStateException("Only CEO can submit final decision");
        }

        // ── 5. Duplicate protection ───────────────────────────────────────────
        if (repository.countExistingDecision(runId, request.participantId(), request.decisionId()) > 0) {
            throw new IllegalStateException("Decision already recorded");
        }

        // ── 6. Validate action exists in decision_options ─────────────────────
        if (repository.countValidOption(request.decisionId(), request.action()) == 0) {
            throw new IllegalStateException("Invalid action for this decision");
        }

        // ── 7. Fetch artifact id ──────────────────────────────────────────────
        UUID artifactId = repository.findArtifactIdByDecisionId(request.decisionId());
        if (artifactId == null) {
            throw new IllegalStateException("Decision not linked to artifact");
        }

        // ── 8. Compute latency band ───────────────────────────────────────────
        LocalDateTime now = LocalDateTime.now();
        String latencyBand = computeLatencyBand(runId, artifactId, now);

        // ── 9. Insert decision event ──────────────────────────────────────────
        repository.insertDecisionEvent(
            runId,
            request.participantId(),
            artifactId,
            request.decisionId(),
            request.action(),
            meta.getDecisionType(),
            latencyBand,
            now
        );

        // ── 10. Apply construct deltas ────────────────────────────────────────
        repository.applyConstructDeltas(runId, request.participantId(), request.decisionId(), request.action());

        // ── 11. Round advancement ─────────────────────────────────────────────
        // Rounds are time-boxed: submitting the CEO's final decision RECORDS the framing but does
        // NOT advance the round. A round advances strictly when its timer ends (Sim1RoundAdvancer),
        // so no team can skip ahead by deciding early, and every team moves on the same clock.
    }

    // ── Latency band helper ───────────────────────────────────────────────────

    private String computeLatencyBand(UUID runId, UUID artifactId, LocalDateTime now) {
        try {
            Object[] window = repository.findArtifactWindow(artifactId, runId);
            if (window == null || window.length < 2) return "MODERATE";

            LocalDateTime openAt    = ((java.sql.Timestamp) window[0]).toLocalDateTime();
            LocalDateTime expiresAt = ((java.sql.Timestamp) window[1]).toLocalDateTime();

            long totalWindow = Duration.between(openAt, expiresAt).toSeconds();
            if (totalWindow <= 0) return "MODERATE";

            long elapsed = Duration.between(openAt, now).toSeconds();
            double ratio = (double) elapsed / totalWindow;

            return ratio <= 0.33 ? "EARLY"
                 : ratio <= 0.66 ? "MODERATE"
                 : "DELAYED";
        } catch (Exception e) {
            return "MODERATE";
        }
    }
    
    /**
     * Logs the "No Response" outcome for every decision this participant could have taken but did not,
     * once its artifact has expired (script 1.7). The outcome is stored as the distinct action SILENCE —
     * deliberately NOT reusing any real option code (the Board Message genuinely offers "Do not respond")
     * — and is surfaced to users as "No Response". It is not a blank: it carries a cost on whichever
     * hidden variables that specific artifact feeds.
     */
    public void processSilence(UUID runId, UUID participantId) {
        // Every artifact poll used to run the (join-heavy) expiry sweep. Nothing can expire until a
        // round actually ends, so at cohort scale that was pure load. Sweep at most once per window per
        // participant; a No Response is still recorded well within the between-rounds gap.
        long now = System.currentTimeMillis();
        Long last = lastSilenceSweep.get(participantId);
        if (last != null && now - last < SILENCE_SWEEP_INTERVAL_MS) {
            return;
        }
        lastSilenceSweep.put(participantId, now);

        var expired = repository.findExpiredUnansweredDecisions(runId, participantId);

        for (Object[] row : expired) {
        	UUID artifactId = UUID.fromString(row[0].toString());
        	UUID decisionId = UUID.fromString(row[1].toString());

            String latencyBand = computeLatencyBand(runId, artifactId, LocalDateTime.now());

            // Idempotent: concurrent polls cannot double-insert (and so cannot double-charge).
            int written = repository.insertSilenceEvent(runId, participantId, artifactId, decisionId, latencyBand);
            if (written > 0) {
                // Indecision is a decision: charge it against the variables this artifact actually feeds.
                repository.applyNoResponsePenalty(runId, participantId, decisionId);
            }
        }
    }
}