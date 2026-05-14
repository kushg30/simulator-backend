package com.example.simulator.dto;

import java.util.UUID;

public record RecordDecisionRequest(
    UUID participantId,
    UUID decisionId,
    String action
) {}
