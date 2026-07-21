#!/usr/bin/env bash
# ============================================================================
# Sim 2 — jump the round clock forward so the T+8 twist appears immediately.
#
# Round 1 releases the Board memo at T+0 and the voided-transactions twist at
# T+8. Rather than waiting 8 real minutes while testing, this back-dates the
# round's start so the twist is already open (~9 minutes left on the clock).
#
#   ./sim2-skip-to-twist.sh              # newest ACTIVE round
#   ./sim2-skip-to-twist.sh <runId>      # a specific run
#   MINUTES=15 ./sim2-skip-to-twist.sh   # jump further (e.g. to expire the twist)
#
# Also prints the per-role URLs for that run.
# ============================================================================
set -euo pipefail

UI=${UI:-http://localhost:3000}
MINUTES=${MINUTES:-9}
PSQL="psql -h 127.0.0.1 -U postgres -d simulator_db -q -t -A"

RUNID=${1:-}
if [ -z "$RUNID" ]; then
  RUNID=$($PSQL -c "SELECT run_id FROM sim2_round_state
                    WHERE status='ACTIVE' ORDER BY started_at DESC LIMIT 1;")
  [ -z "$RUNID" ] && { echo "No ACTIVE Sim-2 round found. Start Round 1 first."; exit 1; }
fi

$PSQL -c "UPDATE sim2_round_state
          SET started_at = started_at - interval '$MINUTES minutes',
              ends_at    = ends_at    - interval '$MINUTES minutes'
          WHERE run_id='$RUNID' AND round_number=1;" >/dev/null

echo "Clock advanced $MINUTES minutes for run $RUNID"
echo

TEAM=$($PSQL -c "SELECT team_id FROM simulation_runs WHERE run_id='$RUNID';")
$PSQL -c "SELECT rp.role || '|' || rp.run_participant_id
          FROM run_participants rp WHERE rp.run_id='$RUNID' ORDER BY rp.role;" |
while IFS='|' read -r ROLE PID; do
  [ -z "$ROLE" ] && continue
  echo "$ROLE:"
  echo "  $UI/sim2/round/1?runId=$RUNID&participantId=$PID&role=$ROLE&teamId=$TEAM"
done

echo
echo "Round 1 answer: 1302602   (plausible-wrong: 1286407)"
