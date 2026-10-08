-- ============================================================================
-- Multi-tenancy, phase 1 — organizations, faculty identities, entitlements, cohorts.
--
-- WHY: every /api/faculty route is guarded by ONE shared token. The moment a second college
-- exists, a facilitator at College A can pause, restart, terminate and read the debrief of
-- College B's live session — and because the debrief queries filter only by simulation_id, both
-- colleges' teams appear in each other's leaderboards. This adds the tenancy layer that was
-- missing so access can be scoped to who the caller actually is.
--
-- SAFETY: additive only. Every new column is nullable, no existing column changes type, nothing
-- is dropped. Runs against a live database with sessions recorded; existing teams and runs keep
-- working untouched and simply have no cohort until one is assigned.
-- ============================================================================

BEGIN;

-- ── the customer ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS organization (
    organization_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name            text NOT NULL,
    -- Used to check that a faculty member's address really belongs to the institution that bought
    -- the simulation. Nullable: some customers will not have a single clean domain.
    email_domain    text,
    status          text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'SUSPENDED')),
    notes           text,
    created_at      timestamp NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS organization_name_key ON organization (lower(name));

-- ── who may open the console ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS faculty_user (
    faculty_user_id   uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id   uuid REFERENCES organization (organization_id),
    name              text NOT NULL,
    email             text NOT NULL,
    -- Only the SHA-256 of the access key is stored. The key itself is shown once, at creation, and
    -- is never recoverable afterwards — the same contract as any API key.
    access_key_hash   text NOT NULL,
    -- Platform staff (us). Sees every organization; has no organization_id of its own.
    is_platform_admin boolean NOT NULL DEFAULT false,
    status            text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'DISABLED')),
    last_seen_at      timestamp,
    created_at        timestamp NOT NULL DEFAULT now(),
    -- A platform admin has no org; everybody else must have one.
    CONSTRAINT faculty_user_org_required
        CHECK (is_platform_admin OR organization_id IS NOT NULL)
);

CREATE UNIQUE INDEX IF NOT EXISTS faculty_user_email_key ON faculty_user (lower(email));
CREATE UNIQUE INDEX IF NOT EXISTS faculty_user_key_hash_key ON faculty_user (access_key_hash);

-- ── what the customer bought ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS entitlement (
    entitlement_id  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organization (organization_id),
    simulation_id   uuid NOT NULL REFERENCES simulations (simulation_id),
    -- NULL seats = no cap. Recorded for the commercial conversation; not enforced in phase 1.
    seats           integer,
    valid_from      date NOT NULL DEFAULT current_date,
    -- NULL = no expiry. Checked on every request, so a lapsed licence closes access on its own.
    valid_until     date,
    notes           text,
    created_at      timestamp NOT NULL DEFAULT now(),
    CONSTRAINT entitlement_unique_per_sim UNIQUE (organization_id, simulation_id)
);

CREATE INDEX IF NOT EXISTS entitlement_org_idx ON entitlement (organization_id);

-- ── a batch the faculty runs ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cohort (
    cohort_id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id uuid NOT NULL REFERENCES organization (organization_id),
    simulation_id   uuid NOT NULL REFERENCES simulations (simulation_id),
    name            text NOT NULL,
    -- Replaces the single global access code shared by every simulation. Per cohort, so a code
    -- handed to one batch cannot open anybody else's session.
    join_code       text NOT NULL,
    created_by      uuid REFERENCES faculty_user (faculty_user_id),
    status          text NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE', 'CLOSED')),
    created_at      timestamp NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS cohort_join_code_active_key
    ON cohort (upper(join_code)) WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS cohort_org_idx ON cohort (organization_id);

-- ── the join from existing play data to a tenant ────────────────────────────
-- Nullable on purpose: every team recorded before this migration has no cohort, and must keep
-- resolving. Queries therefore treat "no cohort" as legacy data visible only to platform admins.
ALTER TABLE team ADD COLUMN IF NOT EXISTS cohort_id uuid REFERENCES cohort (cohort_id);
CREATE INDEX IF NOT EXISTS team_cohort_idx ON team (cohort_id);

COMMIT;
