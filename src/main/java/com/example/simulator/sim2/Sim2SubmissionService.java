package com.example.simulator.sim2;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/**
 * Handles a round submission: store the workbook, grade the typed answer, score the constructs.
 *
 * <p>The uploaded file is retained for faculty review only and is never parsed.
 */
@Service
@Transactional
public class Sim2SubmissionService {

	private final Sim2Repository repository;
	private final Sim2GradingService grading;
	private final Sim2ScoringService scoring;
	private final Path uploadDir;

	public Sim2SubmissionService(Sim2Repository repository, Sim2GradingService grading,
			Sim2ScoringService scoring, @Value("${sim2.upload-dir}") String uploadDir) {
		this.repository = repository;
		this.grading = grading;
		this.scoring = scoring;
		this.uploadDir = Paths.get(uploadDir);
	}

	public Map<String, Object> submit(UUID runId, int roundNumber, UUID participantId, String typedAnswer,
			String confidence, MultipartFile file) {

		// --- guards ---------------------------------------------------------
		String role = repository.findParticipantRole(runId, participantId);
		if (role == null) {
			throw new IllegalStateException("Participant is not part of this run");
		}

		String leadRole = repository.findLeadRole(runId);
		if (leadRole != null && !leadRole.equals(role)) {
			throw new IllegalStateException("Only the " + leadRole + " may submit a round");
		}

		String status = repository.findRoundStatus(runId, roundNumber);
		if (status == null || !"ACTIVE".equals(status)) {
			throw new IllegalStateException("Round " + roundNumber + " is not active (status=" + status + ")");
		}

		if (repository.countSubmissions(runId, roundNumber) > 0) {
			throw new IllegalStateException("Round " + roundNumber + " has already been submitted");
		}

		String conf = confidence == null ? "" : confidence.trim().toUpperCase();
		if (!conf.equals("HIGH") && !conf.equals("MEDIUM") && !conf.equals("LOW")) {
			throw new IllegalStateException("Confidence must be HIGH, MEDIUM or LOW");
		}

		// --- store the file (never parsed) ----------------------------------
		String storedPath = null;
		String originalName = null;
		if (file != null && !file.isEmpty()) {
			originalName = file.getOriginalFilename();
			storedPath = store(runId, roundNumber, file);
		}

		// --- grade ----------------------------------------------------------
		Sim2GradingService.GradeResult result = grading.grade(runId, roundNumber, typedAnswer);

		Integer activeSeconds = repository.findActiveSecondsElapsed(runId, roundNumber);
		Integer durationMin = repository.findRoundDurationMinutes(runId, roundNumber);
		int active = activeSeconds == null ? 0 : activeSeconds;
		int duration = durationMin == null ? 0 : durationMin;

		String scoreDetail = "{\"reason\":\"" + escapeJson(result.reason()) + "\",\"answerType\":\""
				+ escapeJson(result.answerType()) + "\"}";

		repository.insertSubmission(runId, roundNumber, participantId, storedPath, originalName,
				typedAnswer, conf, active, result.correct(), scoreDetail);

		// --- score the constructs -------------------------------------------
		scoring.scoreRound(runId, roundNumber, result.correct(), conf, active, duration);
		repository.completeRound(runId, roundNumber);

		Map<String, Object> response = new LinkedHashMap<>();
		response.put("roundNumber", roundNumber);
		response.put("accepted", true);
		response.put("correct", result.correct());
		response.put("activeSecondsUsed", active);
		response.put("constructs", repository.findConstructScores(runId, roundNumber));
		return response;
	}

	private String store(UUID runId, int roundNumber, MultipartFile file) {
		try {
			Path dir = uploadDir.resolve(runId.toString());
			Files.createDirectories(dir);
			String safeName = "round" + roundNumber + "_" + sanitize(file.getOriginalFilename());
			Path target = dir.resolve(safeName);
			try (var in = file.getInputStream()) {
				Files.copy(in, target, StandardCopyOption.REPLACE_EXISTING);
			}
			return target.toAbsolutePath().toString();
		} catch (IOException e) {
			throw new IllegalStateException("Could not store submission file: " + e.getMessage(), e);
		}
	}

	/** Prevents path traversal via the client-supplied filename. */
	private String sanitize(String name) {
		if (name == null || name.isBlank()) {
			return "submission";
		}
		return Paths.get(name).getFileName().toString().replaceAll("[^A-Za-z0-9._-]", "_");
	}

	private String escapeJson(String s) {
		return s == null ? "" : s.replace("\\", "\\\\").replace("\"", "\\\"");
	}

	@Transactional(readOnly = true)
	public Map<String, Object> getResults(UUID runId, int roundNumber) {
		Map<String, Object> out = new LinkedHashMap<>();
		out.put("roundNumber", roundNumber);
		out.put("submission", repository.findSubmission(runId, roundNumber));
		out.put("constructs", repository.findConstructScores(runId, roundNumber));
		out.put("rollup", repository.findConstructRollup(runId));
		return out;
	}
}
