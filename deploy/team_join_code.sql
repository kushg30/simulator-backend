-- Short, human-readable join code per team (read aloud / written on the board) so
-- students don't have to type the 36-char UUID team id.
ALTER TABLE team ADD COLUMN IF NOT EXISTS join_code varchar(8);
CREATE INDEX IF NOT EXISTS idx_team_join_code ON team (join_code);
