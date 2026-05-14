package com.example.simulator.dto;


import java.time.LocalDateTime;
import java.util.UUID;

public record VisibleArtifactResponse(
    UUID artifactId,
    String artifactType,
    String payload,
    boolean expectedAction,
    Integer roundNumber,
    UUID decisionId,
    String decisionType,
    String decisionOptions,
    String allowedRoles,
    String actionState,   // OPEN | ACTED | LOCKED
    LocalDateTime openAt,
    LocalDateTime expiresAt,
    String chosenAction
) {
	
	 public static VisibleArtifactResponse from(
	            com.example.simulator.projection.VisibleArtifactView v) {

	        return new VisibleArtifactResponse(
	            v.getArtifactId(),
	            v.getArtifactType(),
	            v.getPayload(),
	            v.getExpectedAction(),
	            v.getRoundNumber(),
	            v.getDecisionId(),
	            v.getDecisionType(),
	            v.getDecisionOptions(),
	            v.getAllowedRoles(),
	            v.getActionState(),
	            v.getOpenAt(),
	            v.getExpiresAt(),
	            v.getChosenAction()
	        );
	    }
}



