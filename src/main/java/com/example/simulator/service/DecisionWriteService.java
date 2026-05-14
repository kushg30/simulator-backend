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
    
    public void processSilence(UUID runId, UUID participantId) {
        var expired = repository.findExpiredUnansweredDecisions(runId, participantId);

        for (Object[] row : expired) {
        	UUID artifactId = UUID.fromString(row[0].toString());
        	UUID decisionId = UUID.fromString(row[1].toString());

            String latencyBand = computeLatencyBand(runId, artifactId, LocalDateTime.now());
            
            repository.insertDecisionEvent(
                runId,
                participantId,
                artifactId,
                decisionId,
                "SILENCE",
                "IMPLICIT",
                latencyBand,
                LocalDateTime.now()
            );
        }
    }
}