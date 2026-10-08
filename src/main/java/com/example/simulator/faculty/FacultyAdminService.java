package com.example.simulator.faculty;

import java.security.SecureRandom;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.simulator.config.Validate;

/**
 * Provisioning for the tenancy layer: create a customer, give a facilitator a key, record what they
 * bought.
 *
 * <p>Phase 1 is deliberately operated by hand rather than by a checkout flow. An institution buys
 * on an invoice and a purchase order, not a card on a pricing page, so the useful thing to automate
 * first is <em>access</em>, not payment.
 */
@Service
@Transactional
public class FacultyAdminService {

	private static final SecureRandom RANDOM = new SecureRandom();
	/** Prefix so a leaked key is recognisable in a log or a paste, and greppable. */
	private static final String KEY_PREFIX = "cr_fac_";

	private final FacultyIdentityRepository repo;

	public FacultyAdminService(FacultyIdentityRepository repo) {
		this.repo = repo;
	}

	// ────────────────────────────────────────────────────────── organisations

	public Map<String, Object> createOrganization(String name, String emailDomain, String notes) {
		String cleanName = Validate.requiredText(name, "Organisation name", 120);
		String domain = Validate.optionalText(emailDomain, "Email domain", 120);
		if (domain != null) {
			domain = domain.toLowerCase().replaceFirst("^@", "");
			// A domain, not an address: "sibm.edu.in", never "dean@sibm.edu.in".
			if (!domain.matches("[a-z0-9.-]+\\.[a-z]{2,}")) {
				throw new IllegalArgumentException("Email domain should look like sibm.edu.in");
			}
		}
		UUID id = UUID.randomUUID();
		repo.insertOrganization(id, cleanName, domain,
				Validate.optionalProse(notes, "Notes", 1000));

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("organizationId", id);
		out.put("name", cleanName);
		out.put("emailDomain", domain);
		return out;
	}

	public List<Map<String, Object>> listOrganizations() {
		return repo.findOrganizations();
	}

	// ───────────────────────────────────────────────────────────── faculty

	/**
	 * Creates a facilitator and returns their access key.
	 *
	 * <p>The key is returned <b>once, here, and never again</b> — only its hash is stored, so it
	 * cannot be looked up later. If it is lost, issue a new one and disable the old.
	 */
	public Map<String, Object> createFacultyUser(UUID organizationId, String name, String email,
			boolean platformAdmin) {

		String cleanName = Validate.requiredText(name, "Name", 120);
		String cleanEmail = Validate.requiredText(email, "Email", 190).toLowerCase();
		if (!cleanEmail.matches("[^@\\s]+@[a-z0-9.-]+\\.[a-z]{2,}")) {
			throw new IllegalArgumentException("That does not look like an email address");
		}
		if (!platformAdmin && organizationId == null) {
			throw new IllegalArgumentException("A facilitator must belong to an organisation");
		}

		String key = generateKey();
		UUID id = UUID.randomUUID();
		repo.insertFacultyUser(id, platformAdmin ? null : organizationId, cleanName, cleanEmail,
				FacultyAuthFilter.sha256(key), platformAdmin);

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("facultyUserId", id);
		out.put("name", cleanName);
		out.put("email", cleanEmail);
		out.put("platformAdmin", platformAdmin);
		out.put("accessKey", key);
		out.put("warning", "Copy this key now — it is stored only as a hash and cannot be shown again.");
		return out;
	}

	public List<Map<String, Object>> listFacultyUsers(UUID organizationId) {
		return repo.findFacultyUsers(organizationId);
	}

	public void setFacultyEnabled(UUID facultyUserId, boolean enabled) {
		repo.setFacultyStatus(facultyUserId, enabled ? "ACTIVE" : "DISABLED");
	}

	// ─────────────────────────────────────────────────────────── entitlements

	public Map<String, Object> grantEntitlement(UUID organizationId, UUID simulationId,
			Integer seats, String validUntil, String notes) {

		if (organizationId == null || simulationId == null) {
			throw new IllegalArgumentException("Organisation and simulation are both required");
		}
		if (seats != null) {
			Validate.inRange(seats, "Seats", 1, 100000);
		}
		if (validUntil != null && !validUntil.isBlank()
				&& !validUntil.trim().matches("\\d{4}-\\d{2}-\\d{2}")) {
			throw new IllegalArgumentException("Valid-until should be a date like 2027-06-30");
		}

		UUID id = UUID.randomUUID();
		repo.upsertEntitlement(id, organizationId, simulationId, seats,
				validUntil == null || validUntil.isBlank() ? null : validUntil.trim(),
				Validate.optionalProse(notes, "Notes", 1000));

		Map<String, Object> out = new LinkedHashMap<>();
		out.put("organizationId", organizationId);
		out.put("simulationId", simulationId);
		out.put("seats", seats);
		out.put("validUntil", validUntil);
		return out;
	}

	public List<Map<String, Object>> listEntitlements(UUID organizationId) {
		return repo.findEntitlements(organizationId);
	}

	/** The simulations a caller may act on: everything for platform staff, the licensed set otherwise. */
	public List<UUID> entitledSimulations(FacultyPrincipal principal) {
		if (principal.platformAdmin()) {
			return null; // null means "no restriction" — callers must treat it as unrestricted
		}
		return repo.findEntitledSimulationIds(principal.organizationId());
	}

	/**
	 * 32 bytes of URL-safe randomness. Long enough that guessing is not a threat model, which is
	 * also why the stored form is a plain SHA-256 rather than a slow password hash.
	 */
	private String generateKey() {
		byte[] bytes = new byte[32];
		RANDOM.nextBytes(bytes);
		return KEY_PREFIX + Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
	}
}
