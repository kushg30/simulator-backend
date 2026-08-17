-- Allow the RESTART facilitator action in the audit log (Round Restart control).
ALTER TABLE faculty_actions DROP CONSTRAINT IF EXISTS faculty_actions_action_type_check;
ALTER TABLE faculty_actions ADD CONSTRAINT faculty_actions_action_type_check
  CHECK (action_type = ANY (ARRAY['PAUSE','RESUME','DELAY','BYPASS','INJECT','OVERRIDE','TERMINATE','RESTART']));
