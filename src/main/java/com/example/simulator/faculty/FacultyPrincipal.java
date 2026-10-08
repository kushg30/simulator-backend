package com.example.simulator.faculty;

import java.util.UUID;

/**
 * Who is making a {@code /api/faculty} request.
 *
 * <p>Resolved once by {@link FacultyAuthFilter} and attached to the request, so a controller never
 * has to work out the caller's organisation for itself — the one place that could be forgotten,
 * which is how tenancy leaks happen.
 *
 * @param facultyUserId   the row in {@code faculty_user}, or {@code null} for the legacy token
 * @param organizationId  the organisation this caller belongs to; {@code null} for a platform admin
 * @param name            display name, for the action log
 * @param platformAdmin   platform staff: sees every organisation, bypasses entitlement checks
 * @param legacyToken     authenticated with the old shared token rather than a per-user key
 */
public record FacultyPrincipal(
        UUID facultyUserId,
        UUID organizationId,
        String name,
        boolean platformAdmin,
        boolean legacyToken) {

    /**
     * The identity the pre-tenancy shared token maps to.
     *
     * <p>It is treated as platform staff rather than rejected, so every existing session, script
     * and bookmarked console keeps working through the migration instead of breaking the day this
     * ships. Retiring it is a config change — see {@code faculty.legacy-token-enabled} — not a code
     * change, so it can be switched off the moment every facilitator holds a real key.
     */
    public static FacultyPrincipal legacy() {
        return new FacultyPrincipal(null, null, "Shared token", true, true);
    }

    /** True when this caller may act on data belonging to {@code org}. */
    public boolean canAccessOrganization(UUID org) {
        return platformAdmin || (organizationId != null && organizationId.equals(org));
    }
}
