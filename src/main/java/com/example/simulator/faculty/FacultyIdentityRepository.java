package com.example.simulator.faculty;

import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.simulator.simulation.SimulationRun;

/** Identity, entitlement and provisioning queries for the tenancy layer. */
@Repository
public interface FacultyIdentityRepository
        extends org.springframework.data.repository.Repository<SimulationRun, UUID> {

    // ───────────────────────────────────────────────────────────── identity

    /**
     * Resolve a presented access key to its owner.
     *
     * <p>Looked up by hash, never by the key itself — the key is not stored anywhere. A disabled
     * user, or one whose organisation has been suspended, resolves to nothing and is refused.
     */
    @Query(value = """
            SELECT f.faculty_user_id   AS "facultyUserId",
                   f.organization_id   AS "organizationId",
                   f.name              AS "name",
                   f.is_platform_admin AS "platformAdmin"
            FROM faculty_user f
            LEFT JOIN organization o ON o.organization_id = f.organization_id
            WHERE f.access_key_hash = :keyHash
              AND f.status = 'ACTIVE'
              AND (f.organization_id IS NULL OR o.status = 'ACTIVE')
            """, nativeQuery = true)
    Map<String, Object> findByAccessKeyHash(@Param("keyHash") String keyHash);

    /**
     * Records that a key was used, for "is this account still active / who is running sessions".
     *
     * <p>Carries its own {@code @Transactional}: it is called from the auth filter, which runs
     * outside any transaction, and a {@code @Modifying} query without one is silently discarded —
     * the field stayed null through a dozen authenticated requests before this was added.
     */
    @Modifying
    @org.springframework.transaction.annotation.Transactional
    @Query(value = "UPDATE faculty_user SET last_seen_at = now() WHERE faculty_user_id = :id",
            nativeQuery = true)
    void touchLastSeen(@Param("id") UUID facultyUserId);

    // ────────────────────────────────────────────────────────── entitlement

    /**
     * The simulations an organisation may currently use.
     *
     * <p>The validity window is evaluated here rather than at provisioning time, so a licence that
     * lapses closes access on its own without anybody having to remember to revoke it.
     */
    @Query(value = """
            SELECT e.simulation_id
            FROM entitlement e
            WHERE e.organization_id = :orgId
              AND e.valid_from <= current_date
              AND (e.valid_until IS NULL OR e.valid_until >= current_date)
            """, nativeQuery = true)
    List<UUID> findEntitledSimulationIds(@Param("orgId") UUID orgId);

    // ──────────────────────────────────────────────────────── provisioning

    @Modifying
    @Query(value = """
            INSERT INTO organization (organization_id, name, email_domain, notes)
            VALUES (:id, :name, :domain, :notes)
            """, nativeQuery = true)
    void insertOrganization(@Param("id") UUID id, @Param("name") String name,
            @Param("domain") String emailDomain, @Param("notes") String notes);

    @Modifying
    @Query(value = """
            INSERT INTO faculty_user
                (faculty_user_id, organization_id, name, email, access_key_hash, is_platform_admin)
            VALUES (:id, :orgId, :name, :email, :keyHash, :admin)
            """, nativeQuery = true)
    void insertFacultyUser(@Param("id") UUID id, @Param("orgId") UUID organizationId,
            @Param("name") String name, @Param("email") String email,
            @Param("keyHash") String keyHash, @Param("admin") boolean platformAdmin);

    @Modifying
    @Query(value = """
            INSERT INTO entitlement
                (entitlement_id, organization_id, simulation_id, seats, valid_until, notes)
            VALUES (:id, :orgId, :simId, :seats, CAST(:validUntil AS date), :notes)
            ON CONFLICT (organization_id, simulation_id) DO UPDATE
               SET seats = EXCLUDED.seats,
                   valid_until = EXCLUDED.valid_until,
                   notes = EXCLUDED.notes
            """, nativeQuery = true)
    void upsertEntitlement(@Param("id") UUID id, @Param("orgId") UUID organizationId,
            @Param("simId") UUID simulationId, @Param("seats") Integer seats,
            @Param("validUntil") String validUntil, @Param("notes") String notes);

    @Query(value = """
            SELECT o.organization_id AS "organizationId",
                   o.name            AS "name",
                   o.email_domain    AS "emailDomain",
                   o.status          AS "status",
                   o.created_at      AS "createdAt",
                   (SELECT count(*) FROM faculty_user f WHERE f.organization_id = o.organization_id)
                                     AS "facultyCount",
                   (SELECT count(*) FROM entitlement e WHERE e.organization_id = o.organization_id)
                                     AS "entitlementCount"
            FROM organization o
            ORDER BY o.created_at DESC
            """, nativeQuery = true)
    List<Map<String, Object>> findOrganizations();

    @Query(value = """
            SELECT f.faculty_user_id   AS "facultyUserId",
                   f.name              AS "name",
                   f.email             AS "email",
                   f.status            AS "status",
                   f.is_platform_admin AS "platformAdmin",
                   f.last_seen_at      AS "lastSeenAt",
                   o.name              AS "organizationName"
            FROM faculty_user f
            LEFT JOIN organization o ON o.organization_id = f.organization_id
            WHERE :orgId IS NULL OR f.organization_id = :orgId
            ORDER BY f.created_at DESC
            """, nativeQuery = true)
    List<Map<String, Object>> findFacultyUsers(@Param("orgId") UUID organizationId);

    @Query(value = """
            SELECT e.entitlement_id  AS "entitlementId",
                   e.simulation_id   AS "simulationId",
                   s.name            AS "simulationName",
                   e.seats           AS "seats",
                   e.valid_from      AS "validFrom",
                   e.valid_until     AS "validUntil",
                   o.name            AS "organizationName",
                   e.organization_id AS "organizationId"
            FROM entitlement e
            JOIN organization o ON o.organization_id = e.organization_id
            LEFT JOIN simulations s ON s.simulation_id = e.simulation_id
            WHERE :orgId IS NULL OR e.organization_id = :orgId
            ORDER BY o.name, s.name
            """, nativeQuery = true)
    List<Map<String, Object>> findEntitlements(@Param("orgId") UUID organizationId);

    @Modifying
    @Query(value = "UPDATE faculty_user SET status = :status WHERE faculty_user_id = :id",
            nativeQuery = true)
    void setFacultyStatus(@Param("id") UUID facultyUserId, @Param("status") String status);

    // ───────────────────────────────────────────────────────────── cohorts

    /**
     * Whether an organisation currently holds a usable licence for a simulation.
     *
     * <p>Checked when a cohort is created, which is the choke point: a batch can only exist for
     * something the institution actually bought, and every team and student inherits its scope from
     * the cohort they join.
     */
    @Query(value = """
            SELECT EXISTS (
              SELECT 1 FROM entitlement e
              WHERE e.organization_id = :orgId
                AND e.simulation_id = :simId
                AND e.valid_from <= current_date
                AND (e.valid_until IS NULL OR e.valid_until >= current_date))
            """, nativeQuery = true)
    boolean isEntitled(@Param("orgId") UUID organizationId, @Param("simId") UUID simulationId);

    @Query(value = "SELECT EXISTS (SELECT 1 FROM cohort WHERE upper(join_code) = upper(:code)"
            + " AND status = 'ACTIVE')", nativeQuery = true)
    boolean joinCodeTaken(@Param("code") String joinCode);

    @Modifying
    @Query(value = """
            INSERT INTO cohort (cohort_id, organization_id, simulation_id, name, join_code, created_by)
            VALUES (:id, :orgId, :simId, :name, :joinCode, :createdBy)
            """, nativeQuery = true)
    void insertCohort(@Param("id") UUID id, @Param("orgId") UUID organizationId,
            @Param("simId") UUID simulationId, @Param("name") String name,
            @Param("joinCode") String joinCode, @Param("createdBy") UUID createdBy);

    /** Cohorts visible to the caller: their own organisation's, or all of them for platform staff. */
    @Query(value = """
            SELECT c.cohort_id       AS "cohortId",
                   c.name            AS "name",
                   c.join_code       AS "joinCode",
                   c.simulation_id   AS "simulationId",
                   s.name            AS "simulationName",
                   c.status          AS "status",
                   c.created_at      AS "createdAt",
                   o.name            AS "organizationName",
                   (SELECT count(*) FROM team t WHERE t.cohort_id = c.cohort_id) AS "teamCount"
            FROM cohort c
            JOIN organization o ON o.organization_id = c.organization_id
            LEFT JOIN simulations s ON s.simulation_id = c.simulation_id
            WHERE :platformAdmin = true OR c.organization_id = CAST(:orgId AS uuid)
            ORDER BY c.created_at DESC
            """, nativeQuery = true)
    List<Map<String, Object>> findCohorts(@Param("platformAdmin") boolean platformAdmin,
            @Param("orgId") String organizationId);

    @Modifying
    @Query(value = """
            UPDATE cohort SET status = :status
            WHERE cohort_id = :id
              AND (:platformAdmin = true OR organization_id = CAST(:orgId AS uuid))
            """, nativeQuery = true)
    int setCohortStatus(@Param("id") UUID cohortId, @Param("status") String status,
            @Param("platformAdmin") boolean platformAdmin, @Param("orgId") String organizationId);
}
