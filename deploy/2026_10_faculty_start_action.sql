-- ============================================================================
-- Allow START in the facilitator action log.
--
-- WHY: the facilitator can now start a team's run from the console, and every facilitator action is
-- written to faculty_actions. The action_type CHECK does not list START, so the log insert would
-- fail and take the whole start transaction down with it — the run would never begin, and the
-- error would read as a database fault rather than a missing enum value.
--
-- SAFETY: widens an existing CHECK. No data is read or changed, and every value that was valid
-- before is still valid.
-- ============================================================================

BEGIN;

ALTER TABLE faculty_actions DROP CONSTRAINT IF EXISTS faculty_actions_action_type_check;

ALTER TABLE faculty_actions ADD CONSTRAINT faculty_actions_action_type_check
    CHECK (action_type = ANY (ARRAY[
        'PAUSE', 'RESUME', 'DELAY', 'BYPASS', 'INJECT', 'OVERRIDE',
        'TERMINATE', 'RESTART', 'NEWS', 'TIMEOUT',
        'START'
    ]));

COMMIT;
