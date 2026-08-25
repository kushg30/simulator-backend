-- Sim 1 Set-B scoring, Phase 1: the per-option construct mapping table.
-- Each of the five canonical constructs is moved by 1-3 of an option's deltas.
CREATE TABLE IF NOT EXISTS sim1_option_constructs (
  option_id      uuid    NOT NULL REFERENCES decision_options(option_id) ON DELETE CASCADE,
  construct_name text    NOT NULL,
  base_delta     integer NOT NULL,
  PRIMARY KEY (option_id, construct_name)
);
CREATE INDEX IF NOT EXISTS idx_sim1_opt_constructs_option ON sim1_option_constructs(option_id);
