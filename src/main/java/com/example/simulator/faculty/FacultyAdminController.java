package com.example.simulator.faculty;

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
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.example.simulator.config.Validate;

/**
 * Provisioning endpoints: create a customer, issue a facilitator key, record a licence.
 *
 * <p>Everything here is <b>platform staff only</b>. It sits under {@code /api/faculty} so the auth
 * filter already covers it, and then narrows further — a facilitator at a customer institution
 * authenticates fine for the console but must not be able to mint themselves a licence for a
 * simulation their college never bought.
 *
 * <p>The principal is injected straight from the request attribute the auth filter sets, so there
 * is no second place that could decide who the caller is and get it wrong.
 */
@RestController
@RequestMapping("/api/faculty/admin")
public class FacultyAdminController {

	private final FacultyAdminService service;

	public FacultyAdminController(FacultyAdminService service) {
		this.service = service;
	}

	/** Every route in this controller passes through here first. */
	private void requirePlatformAdmin(FacultyPrincipal principal) {
		if (principal == null || !principal.platformAdmin()) {
			throw new FacultyForbiddenException("This action is restricted to CaseRun staff");
		}
	}

	private static FacultyPrincipal self(FacultyPrincipal p) {
		return p;
	}

	// ───────────────────────────────────────────────────────────── whoami

	/**
	 * Who the presented credential belongs to. The console calls this on sign-in to learn whether
	 * to show the admin tools, and which organisation it is looking at.
	 */
	@GetMapping("/whoami")
	public Map<String, Object> whoami(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal) {
		List<UUID> entitled = service.entitledSimulations(principal);
		return Map.of(
				"name", principal.name(),
				"platformAdmin", principal.platformAdmin(),
				"legacyToken", principal.legacyToken(),
				"organizationId", principal.organizationId() == null ? "" : principal.organizationId(),
				// An empty list means "entitled to nothing"; absent means "unrestricted".
				"entitledSimulationIds", entitled == null ? List.of() : entitled,
				"unrestricted", entitled == null);
	}

	// ─────────────────────────────────────────────────────── organisations

	@PostMapping("/organizations")
	public ResponseEntity<?> createOrganization(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal,
			@RequestBody Map<String, String> body) {
		requirePlatformAdmin(self(principal));
		return ResponseEntity.ok(service.createOrganization(
				body.get("name"), body.get("emailDomain"), body.get("notes")));
	}

	@GetMapping("/organizations")
	public List<Map<String, Object>> listOrganizations(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal) {
		requirePlatformAdmin(principal);
		return service.listOrganizations();
	}

	// ────────────────────────────────────────────────────────────── faculty

	@PostMapping("/faculty-users")
	public ResponseEntity<?> createFacultyUser(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal,
			@RequestBody Map<String, Object> body) {
		requirePlatformAdmin(principal);
		UUID orgId = Validate.optionalUuid(str(body.get("organizationId")), "organizationId");
		boolean admin = Boolean.TRUE.equals(body.get("platformAdmin"));
		return ResponseEntity.ok(service.createFacultyUser(
				orgId, str(body.get("name")), str(body.get("email")), admin));
	}

	@GetMapping("/faculty-users")
	public List<Map<String, Object>> listFacultyUsers(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal,
			@RequestParam(value = "organizationId", required = false) String organizationId) {
		requirePlatformAdmin(principal);
		return service.listFacultyUsers(Validate.optionalUuid(organizationId, "organizationId"));
	}

	@PostMapping("/faculty-users/{facultyUserId}/disable")
	public ResponseEntity<?> disable(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal,
			@PathVariable UUID facultyUserId) {
		requirePlatformAdmin(principal);
		service.setFacultyEnabled(facultyUserId, false);
		return ResponseEntity.ok(Map.of("disabled", true));
	}

	@PostMapping("/faculty-users/{facultyUserId}/enable")
	public ResponseEntity<?> enable(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal,
			@PathVariable UUID facultyUserId) {
		requirePlatformAdmin(principal);
		service.setFacultyEnabled(facultyUserId, true);
		return ResponseEntity.ok(Map.of("enabled", true));
	}

	// ────────────────────────────────────────────────────────── licences

	@PostMapping("/entitlements")
	public ResponseEntity<?> grant(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal,
			@RequestBody Map<String, Object> body) {
		requirePlatformAdmin(principal);
		Integer seats = body.get("seats") == null ? null
				: Integer.valueOf(String.valueOf(body.get("seats")));
		return ResponseEntity.ok(service.grantEntitlement(
				Validate.uuid(str(body.get("organizationId")), "organizationId"),
				Validate.uuid(str(body.get("simulationId")), "simulationId"),
				seats, str(body.get("validUntil")), str(body.get("notes"))));
	}

	@GetMapping("/entitlements")
	public List<Map<String, Object>> listEntitlements(
			@RequestAttribute(FacultyAuthFilter.PRINCIPAL_ATTRIBUTE) FacultyPrincipal principal,
			@RequestParam(value = "organizationId", required = false) String organizationId) {
		requirePlatformAdmin(principal);
		return service.listEntitlements(Validate.optionalUuid(organizationId, "organizationId"));
	}

	private static String str(Object o) {
		return o == null ? null : String.valueOf(o);
	}
}
