-- v6 Round 2 Breaking-News confidence revision: the team may revise its stated R2
-- confidence after the Breaking News interrupt; recorded separately from the original.
ALTER TABLE sim2_submissions ADD COLUMN IF NOT EXISTS revised_confidence text;
