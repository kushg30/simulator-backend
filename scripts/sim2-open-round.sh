#!/usr/bin/env bash
# ============================================================================
# Sim 2 — open the current round fully so every artifact is released.
#
# Each Meridian round runs 18-24 minutes and drips artifacts out on a timer.
# While testing you rarely want to sit through that, so this winds the round
# clock forward far enough that everything in it is visible, while leaving
# plenty of time left to actually submit.
#
#   ./sim2-open-round.sh              # newest ACTIVE round of any run
#   ./sim2-open-round.sh <runId>      # a specific run
#
# Prints the per-role URLs and the expected answer for that round.
# ============================================================================
set -euo pipefail

UI=${UI:-http://localhost:3000}
PSQL="psql -h 127.0.0.1 -U postgres -d simulator_db -q -t -A"

RUNID=${1:-}
if [ -z "$RUNID" ]; then
  RUNID=$($PSQL -c "SELECT run_id FROM sim2_round_state WHERE status='ACTIVE'
                    ORDER BY started_at DESC LIMIT 1;")
  [ -z "$RUNID" ] && { echo "No ACTIVE round found. Start a round first."; exit 1; }
fi

ROUND=$($PSQL -c "SELECT round_number FROM sim2_round_state
                  WHERE run_id='$RUNID' AND status='ACTIVE'
                  ORDER BY round_number DESC LIMIT 1;")
[ -z "$ROUND" ] && { echo "No ACTIVE round for run $RUNID"; exit 1; }

# Wind the clock so all artifacts have opened, keeping 20 minutes on the timer.
$PSQL -c "UPDATE sim2_round_state
          SET started_at = now() - interval '16 minutes',
              ends_at    = now() + interval '20 minutes'
          WHERE run_id='$RUNID' AND round_number=$ROUND;" >/dev/null

# Clear any pause so the clock is actually moving.
$PSQL -c "UPDATE run_round_clock SET paused_at=NULL
          WHERE run_id='$RUNID' AND round_number=$ROUND;" >/dev/null

TEAM=$($PSQL -c "SELECT team_id FROM simulation_runs WHERE run_id='$RUNID';")
ANSWER=$($PSQL -c "SELECT k.canonical_answer FROM sim2_answer_key k
                   JOIN simulation_runs sr ON sr.simulation_id = k.simulation_id
                   WHERE sr.run_id='$RUNID' AND k.round_number=$ROUND;")
QUESTION=$($PSQL -c "SELECT k.question FROM sim2_answer_key k
                     JOIN simulation_runs sr ON sr.simulation_id = k.simulation_id
                     WHERE sr.run_id='$RUNID' AND k.round_number=$ROUND;")

echo "Round $ROUND opened — all artifacts released, 20 minutes on the clock."
echo
echo "Q: $QUESTION"
echo "A: $ANSWER"
echo
$PSQL -c "SELECT rp.role || '|' || rp.run_participant_id FROM run_participants rp
          WHERE rp.run_id='$RUNID' ORDER BY rp.role;" |
while IFS='|' read -r ROLE PID; do
  [ -z "$ROLE" ] && continue
  echo "$ROLE:"
  echo "  $UI/sim2/round/$ROUND?runId=$RUNID&participantId=$PID&role=$ROLE&teamId=$TEAM"
done
