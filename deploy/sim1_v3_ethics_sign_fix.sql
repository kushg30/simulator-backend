-- Ethical Exposure is an ADVERSE hidden variable: higher = worse (script 1.9, and the facilitator
-- console already treats it as adverse alongside Organizational Risk). The seeded Set-A deltas had the
-- sign inverted — the MOST responsible option (e.g. "Flag uncertainty", "Issue guidance encouraging
-- escalation", the Governance framing) carried ethics +10, which RAISED exposure, while the least
-- defensible option lowered it. That inverts the reveal and the console's adverse flagging.
--
-- Flip the sign so a cautious/responsible choice LOWERS Ethical Exposure and a less-defensible one
-- raises it. Trust / Organizational Risk / Execution Quality were already correct and are untouched.
BEGIN;

UPDATE decision_options o SET ethics_delta = -o.ethics_delta
FROM decisions d
JOIN artifacts a ON a.artifact_id = d.artifact_id
JOIN rounds r ON r.round_id = a.round_id
WHERE o.decision_id = d.decision_id
  AND r.simulation_id = '475db739-0708-48d4-b4db-5a23f1da50d9';

COMMIT;
