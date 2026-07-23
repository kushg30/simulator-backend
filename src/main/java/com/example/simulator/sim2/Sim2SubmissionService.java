package com.example.simulator.sim2;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.LinkedHashMap;
import java.util.List;
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
	private final Sim2DebriefService debrief;
	private final Path uploadDir;

	public Sim2SubmissionService(Sim2Repository repository, Sim2GradingService grading,
			Sim2ScoringService scoring, Sim2DebriefService debrief,
			@Value("${sim2.upload-dir:./uploads}") String uploadDir) {
		this.repository = repository;
		this.grading = grading;
		this.scoring = scoring;
		this.debrief = debrief;
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
		// A paused round is frozen: the team cannot submit until the facilitator resumes.
		if (Boolean.TRUE.equals(repository.isRoundPaused(runId, roundNumber))) {
			throw new IllegalStateException("The round is paused; please wait for the facilitator to resume");
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

		Integer activeSeconds = repository.findActiveSecondsElapsed(runId, roundNumber);
		Integer durationMin = repository.findRoundDurationMinutes(runId, roundNumber);
		int active = activeSeconds == null ? 0 : activeSeconds;
		int duration = durationMin == null ? 0 : durationMin;

		// --- grade (or not, for a free-text round) --------------------------
		Boolean correct;
		String scoreDetail;
		if (grading.isGradable(runId, roundNumber)) {
			Sim2GradingService.GradeResult result = grading.grade(runId, roundNumber, typedAnswer);
			correct = result.correct();
			scoreDetail = "{\"reason\":\"" + escapeJson(result.reason()) + "\",\"answerType\":\""
					+ escapeJson(result.answerType()) + "\"}";
			scoring.scoreRound(runId, roundNumber, correct, conf, active, duration);
		} else {
			// Free-text consolidation round: no correctness, Turnaround Discipline only.
			correct = null;
			scoreDetail = "{\"reason\":\"free-text, not graded\",\"answerType\":\"FREE_TEXT\"}";
			scoring.scoreRoundNoAnswer(runId, roundNumber, active, duration);
		}

		repository.insertSubmission(runId, roundNumber, participantId, storedPath, originalName,
				typedAnswer, conf, active, correct, scoreDetail);
		repository.completeRound(runId, roundNumber);

		// The last round triggers the run-level final reveal (Data Trust Score and
		// Insight Communication, plus the rolled-up means).
		Integer nextRound = repository.findNextRoundNumber(runId, roundNumber);
		if (nextRound == null) {
			scoring.finalizeEngagement(runId);
		}

		Map<String, Object> response = new LinkedHashMap<>();
		response.put("roundNumber", roundNumber);
		response.put("accepted", true);
		response.put("correct", correct);
		response.put("activeSecondsUsed", active);
		response.put("constructs", repository.findConstructScores(runId, roundNumber));
		response.put("nextRound", nextRound);
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
		out.put("nextRound", repository.findNextRoundNumber(runId, roundNumber));
		// Present only once the engagement is complete: the finalised five-construct
		// reveal (round 0), including the two run-level constructs.
		List<Map<String, Object>> finalReveal = repository.findFinalScores(runId);
		out.put("finalReveal", finalReveal);
		// The team's own standing in the cohort per construct. A team only sees where it
		// sits, not the whole leaderboard; that is faculty-facing.
		if (!finalReveal.isEmpty()) {
			out.put("cohortStanding", debrief.teamStanding(repository.findSimulationId(runId), runId));
		}
		return out;
	}
}
