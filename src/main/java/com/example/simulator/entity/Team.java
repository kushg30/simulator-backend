package com.example.simulator.entity;

import java.util.UUID;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.Id;

@Entity
public class Team {

    @Id
    @GeneratedValue
    private UUID teamId;

    private String teamName;

    private boolean locked = false;

    /** Which simulation this team is playing. Null is treated as Simulation 1. */
    private UUID simulationId;

	public UUID getSimulationId() {
		return simulationId;
	}

	public void setSimulationId(UUID simulationId) {
		this.simulationId = simulationId;
	}

	public UUID getTeamId() {
		return teamId;
	}

	public void setTeamId(UUID teamId) {
		this.teamId = teamId;
	}

	public String getTeamName() {
		return teamName;
	}

	public void setTeamName(String teamName) {
		this.teamName = teamName;
	}

	public boolean isLocked() {
		return locked;
	}

	public void setLocked(boolean locked) {
		this.locked = locked;
	}

    
}
