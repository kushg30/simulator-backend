package com.example.simulator.simulation;

import java.util.UUID;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

@Entity
@Table(name = "simulation_runs")
public class SimulationRun {

    @Id
    @Column(name = "run_id")
    private UUID runId;

    // other fields (can be minimal for now)
}
