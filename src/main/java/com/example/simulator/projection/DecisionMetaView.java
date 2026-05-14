package com.example.simulator.projection;

import java.util.UUID;

public interface DecisionMetaView {
    UUID getDecisionId();
    String getDecisionType();
    Boolean getIsFinal();
    String getAllowedRoles(); // JSON text
}

