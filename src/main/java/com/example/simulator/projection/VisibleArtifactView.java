package com.example.simulator.projection;

import java.time.LocalDateTime;
import java.util.UUID;

public interface VisibleArtifactView {

    UUID getArtifactId();
    String getArtifactType();
    String getPayload(); // JSON string
    Boolean getExpectedAction();

    Integer getRoundNumber();

    LocalDateTime getOpenAt();
    LocalDateTime getExpiresAt();

    UUID getDecisionId();
    String getDecisionType();
    String getAllowedRoles(); // JSON array as string

    String getActionState(); // OPEN | ACTED | EXPIRED | READ_ONLY
    String getDecisionOptions();
    String getChosenAction();
}

