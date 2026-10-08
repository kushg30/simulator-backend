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

    @Modifying
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
}
