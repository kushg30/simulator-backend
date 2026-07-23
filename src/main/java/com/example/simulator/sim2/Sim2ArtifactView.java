package com.example.simulator.sim2;

import java.time.LocalDateTime;
import java.util.UUID;

/** Projection for a Sim-2 artifact as seen by one participant in one round. */
public interface Sim2ArtifactView {

	UUID getArtifactId();

	String getArtifactType();

	String getPayload(); // JSON string

	Boolean getExpectedAction();

	Integer getRoundNumber();

	LocalDateTime getOpenAt();

	LocalDateTime getExpiresAt();

	UUID getDecisionId();

	String getDecisionType();

	String getDecisionOptions(); // JSON array as string

	String getChosenAction();

	String getActionState(); // OPEN | ACTED | EXPIRED | READ_ONLY
}
