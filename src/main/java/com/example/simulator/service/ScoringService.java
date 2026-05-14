package com.example.simulator.service;

import java.util.HashMap;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.simulator.repository.ArtifactQueryRepository;


@Service
@Transactional(readOnly = true)
public class ScoringService {

    private final ArtifactQueryRepository repository;

    public ScoringService(ArtifactQueryRepository repository) {
        this.repository = repository;
    }

    public Map<UUID, Map<String, Integer>> getScores(UUID runId) {

        Map<UUID, Map<String, Integer>> result = new HashMap<>();

        for (Object[] row : repository.computeScores(runId)) {
            UUID participantId = (UUID) row[0];

            Map<String, Integer> scores = Map.of(
                "trust", ((Number) row[1]).intValue(),
                "risk", ((Number) row[2]).intValue(),
                "ethics", ((Number) row[3]).intValue(),
                "execution", ((Number) row[4]).intValue()
            );

            result.put(participantId, scores);
        }
        return result;
    }
}

