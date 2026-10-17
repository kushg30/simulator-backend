package com.example.simulator.faculty;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.simulator.service.RunService;

/**
 * The assembly phase — teams that have gathered but not yet begun, and the controls to begin them.
 *
 * <p>The console's main list is built from runs, so for the several minutes while students form
 * teams and claim roles it shows nothing and the facilitator is blind. Worse, only a team's own
 * lead could start a run, so a facilitator could neither see the room nor start it: they had to ask
 * out loud whether everyone was in. This is both halves of that gap.
 */
@RestController
@RequestMapping("/api/faculty")
public class TeamsFormingController {

	private final FacultyIdentityRepository repo;
	private final RunService runService;
	private final FacultyService facultyService;

	public TeamsFormingController(FacultyIdentityRepository repo, RunService runService,
			FacultyService facultyService) {
		this.repo = repo;
		this.runService = runService;
		this.facultyService = facultyService;
	}

	/** Teams in the caller's batches that have not started, with their seat state. */
	@GetMapping("/teams-forming")
	public List<Map<String, Object>> teamsForming(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal) {
		return repo.findTeamsForming(principal.platformAdmin(), orgParam(principal));
	}

	/**
	 * Start one team's run.
	 *
	 * <p>Readiness is left to {@link RunService#startRun}, which refuses a team whose seats are not
	 * all filled and returns the existing run if one somehow already exists. Re-implementing that
	 * check here would be a second definition of "ready" to drift out of step with the first.
	 */
	@PostMapping("/teams/{teamId}/start")
	public ResponseEntity<?> startTeam(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal,
			@PathVariable UUID teamId,
			@RequestBody(required = false) Map<String, String> body) {

		requireTeamInScope(principal, teamId);
		Map<String, Object> run = runService.startRun(teamId);
		logStart(principal, run, body, "TEAM");
		return ResponseEntity.ok(run);
	}

	/**
	 * Start every not-yet-started team in a batch.
	 *
	 * <p>Teams that are not ready are reported rather than aborting the whole thing — with a dozen
	 * teams in a room, one still missing a role must not stop the other eleven from beginning.
	 */
	@PostMapping("/cohorts/{cohortId}/start-all")
	public ResponseEntity<?> startAll(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal,
			@PathVariable UUID cohortId,
			@RequestBody(required = false) Map<String, String> body) {

		UUID owner = repo.findCohortOrganization(cohortId);
		if (owner == null || !principal.canAccessOrganization(owner)) {
			throw new FacultyForbiddenException("That batch does not belong to your institution");
		}

		List<Map<String, Object>> started = new ArrayList<>();
		List<Map<String, Object>> skipped = new ArrayList<>();
		for (UUID teamId : repo.findUnstartedTeamIds(cohortId)) {
			try {
				Map<String, Object> run = runService.startRun(teamId);
				logStart(principal, run, body, "ALL");
				started.add(Map.of("teamId", teamId));
			} catch (RuntimeException e) {
				// Almost always "seats not filled". Reported per team so the facilitator knows
				// exactly who to chase, instead of a single failure for the whole batch.
				skipped.add(Map.of("teamId", teamId, "reason", String.valueOf(e.getMessage())));
			}
		}

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("started", started.size());
		out.put("skipped", skipped);
		return ResponseEntity.ok(out);
	}

	/** A start acts on somebody's live classroom, so the id in the URL is never taken on trust. */
	private void requireTeamInScope(FacultyPrincipal principal, UUID teamId) {
		UUID owner = repo.findTeamOrganization(teamId);
		if (owner == null) {
			// No cohort: a pre-tenancy or demo team, which only platform staff may touch.
			if (!principal.platformAdmin()) {
				throw new FacultyForbiddenException("That team does not belong to your institution");
			}
			return;
		}
		if (!principal.canAccessOrganization(owner)) {
			throw new FacultyForbiddenException("That team does not belong to your institution");
		}
	}

	private void logStart(FacultyPrincipal principal, Map<String, Object> run,
			Map<String, String> body, String scope) {
		Object runId = run == null ? null : run.get("runId");
		if (!(runId instanceof UUID id)) {
			return; // nothing to attribute the action to
		}
		String actor = body == null ? null : body.get("actor");
		facultyService.logTeamStart(id, scope,
				actor == null || actor.isBlank() ? principal.name() : actor);
	}

	private static String orgParam(FacultyPrincipal principal) {
		return principal.organizationId() == null ? null : principal.organizationId().toString();
	}
}
