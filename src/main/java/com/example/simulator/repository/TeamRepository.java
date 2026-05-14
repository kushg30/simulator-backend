package com.example.simulator.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import com.example.simulator.entity.Team;

@Repository
public interface TeamRepository extends JpaRepository<Team, UUID> {
}
