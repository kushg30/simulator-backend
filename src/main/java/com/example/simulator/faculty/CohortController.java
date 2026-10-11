package com.example.simulator.faculty;

import java.security.SecureRandom;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestAttribute;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.example.simulator.config.Validate;

/**
 * Cohorts — the batch a facilitator actually runs.
 *
 * <p>This is the choke point that makes an entitlement mean something. A cohort may only be created
 * for a simulation the caller's institution currently holds a licence for, and every team inherits
 * its tenancy from the cohort it belongs to. So "a college's students cannot reach a simulation the
 * college did not buy" is enforced once, here, rather than re-checked in a dozen places that could
 * each be forgotten.
 */
@RestController
@RequestMapping("/api/faculty/cohorts")
public class CohortController {

	private static final SecureRandom RANDOM = new SecureRandom();
	/** No I/O/0/1 — these are read aloud in a lecture hall and typed by sixty people at once. */
	private static final String CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
	private static final int CODE_LENGTH = 6;

	private final FacultyIdentityRepository repo;

	public CohortController(FacultyIdentityRepository repo) {
		this.repo = repo;
	}

	@PostMapping
	@Transactional
	public ResponseEntity<?> create(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal,
			@RequestBody Map<String, String> body) {

		UUID simulationId = Validate.uuid(body.get("simulationId"), "simulationId");
		String name = Validate.requiredText(body.get("name"), "Batch name", 120);

		// A platform admin may create a cohort for any organisation (they run pilots and fix things
		// up); everybody else gets their own, and cannot name a different one.
		UUID organizationId = principal.platformAdmin()
				? Validate.uuid(body.get("organizationId"), "organizationId")
				: principal.organizationId();
		if (organizationId == null) {
			throw new FacultyForbiddenException("This account is not attached to an institution");
		}

		// The entitlement check. Skipped for platform staff so a licence can be demoed or repaired
		// before it is recorded, but never skipped for a customer.
		if (!principal.platformAdmin() && !repo.isEntitled(organizationId, simulationId)) {
			throw new FacultyForbiddenException(
					"Your institution does not have an active licence for that simulation");
		}

		UUID id = UUID.randomUUID();
		String joinCode = generateJoinCode();
		repo.insertCohort(id, organizationId, simulationId, name, joinCode,
				principal.facultyUserId());

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("cohortId", id);
		out.put("name", name);
		out.put("joinCode", joinCode);
		out.put("simulationId", simulationId);
		return ResponseEntity.ok(out);
	}

	@GetMapping
	public List<Map<String, Object>> list(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal) {
		return repo.findCohorts(principal.platformAdmin(), orgParam(principal));
	}

	/** Closing a cohort retires its join code so the batch cannot be re-entered next term. */
	@PostMapping("/{cohortId}/close")
	@Transactional
	public ResponseEntity<?> close(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal,
			@PathVariable UUID cohortId) {

		// The update carries the tenancy predicate itself, so a cohort belonging to another
		// institution matches nothing rather than being closed by a guessed id.
		int updated = repo.setCohortStatus(cohortId, "CLOSED", principal.platformAdmin(),
				orgParam(principal));
		if (updated == 0) {
			throw new FacultyForbiddenException("That batch does not belong to your institution");
		}
		return ResponseEntity.ok(Map.of("closed", true));
	}

	private static String orgParam(FacultyPrincipal principal) {
		return principal.organizationId() == null ? null : principal.organizationId().toString();
	}

	/**
	 * A short code students type. Retried on collision against currently-active cohorts, so a code
	 * is unambiguous while it is in use but can be reused once a batch is closed.
	 */
	private String generateJoinCode() {
		for (int attempt = 0; attempt < 40; attempt++) {
			StringBuilder sb = new StringBuilder(CODE_LENGTH);
			for (int i = 0; i < CODE_LENGTH; i++) {
				sb.append(CODE_ALPHABET.charAt(RANDOM.nextInt(CODE_ALPHABET.length())));
			}
			String code = sb.toString();
			if (!repo.joinCodeTaken(code)) {
				return code;
			}
		}
		throw new IllegalStateException("Could not allocate a batch code — please try again");
	}
}
