#!/usr/bin/env bash
# ============================================================================
# Sim 2 (Meridian Retail QBR) — dev helper.
#
# Sets up a ready-to-drive team so you can test in the browser without opening
# six tabs: it creates the team, fills the five non-lead roles with bots,
# starts the run and Round 1, and prints the URLs to open.
#
#   ./sim2-dev-team.sh              # normal 18-minute round, twist lands at T+8
#   ./sim2-dev-team.sh --skip-to-twist   # back-dates the clock so the twist is
#                                        # visible immediately (9 min left)
#
# Requires the backend on :8080 and the frontend on :3000.
# ============================================================================
set -euo pipefail

API=${API:-http://localhost:8080}
UI=${UI:-http://localhost:3000}
SIM2=5116d200-0000-4000-a000-000000000002
PSQL="psql -h 127.0.0.1 -U postgres -d simulator_db -q -t -A"

SKIP_TO_TWIST=0
[ "${1:-}" = "--skip-to-twist" ] && SKIP_TO_TWIST=1

json_field () { sed -E "s/.*\"$2\":\"([^\"]+)\".*/\1/" <<<"$1"; }

TEAM_NAME="Dev-$(date +%H%M%S)"
echo "Creating team '$TEAM_NAME'…"
CREATE=$(curl -s -X POST "$API/api/teams" -H 'Content-Type: application/json' \
  -d "{\"teamName\":\"$TEAM_NAME\",\"participantName\":\"You (Team Lead)\",\"simulationId\":\"$SIM2\"}")
TEAM=$(json_field "$CREATE" teamId)
LEAD=$(json_field "$CREATE" participantId)

declare -A OTHERS
for ROLE in DATA_QUALITY_ANALYST CATEGORY_REGIONAL_ANALYST REPORTING_DASHBOARD_ANALYST \
            PEOPLE_ANALYTICS_ASSOCIATE AUTOMATION_BI_ASSOCIATE; do
  PJ=$(curl -s -X POST "$API/api/teams/$TEAM/join" -H 'Content-Type: application/json' \
        -d "{\"participantName\":\"bot-$ROLE\"}")
  PID=$(json_field "$PJ" participantId)
  curl -s -o /dev/null -X POST "$API/api/teams/$TEAM/assign-role" \
    -H 'Content-Type: application/json' \
    -d "{\"participantId\":\"$PID\",\"role\":\"$ROLE\"}"
  OTHERS[$ROLE]=$PID
  echo "  filled $ROLE"
done

RUN=$(curl -s -X POST "$API/api/runs/start/$TEAM")
RUNID=$(json_field "$RUN" runId)
curl -s -o /dev/null -X POST "$API/api/sim2/runs/$RUNID/rounds/1/start"
echo "Run started: $RUNID"

if [ "$SKIP_TO_TWIST" = "1" ]; then
  $PSQL -c "UPDATE sim2_round_state SET started_at = started_at - interval '9 minutes',
            ends_at = ends_at - interval '9 minutes'
            WHERE run_id='$RUNID' AND round_number=1;" >/dev/null
  echo "Clock back-dated 9 min — the twist is visible now, ~9 min left on the round."
fi

DQA=${OTHERS[DATA_QUALITY_ANALYST]}
cat <<EOF

────────────────────────────────────────────────────────────────────
OPEN THESE
────────────────────────────────────────────────────────────────────
Team Lead (you — submits the round):
  $UI/sim2/round/1?runId=$RUNID&participantId=$LEAD&role=TEAM_LEAD&teamId=$TEAM

Data Quality Analyst (owns Round 1, sees + answers the twist):
  $UI/sim2/round/1?runId=$RUNID&participantId=$DQA&role=DATA_QUALITY_ANALYST&teamId=$TEAM

Results (after you submit):
  $UI/sim2/results/1?runId=$RUNID&participantId=$LEAD&role=TEAM_LEAD&teamId=$TEAM

Correct answer for Round 1: 1302602      (wrong-but-plausible: 1286407)
teamId=$TEAM
runId=$RUNID
────────────────────────────────────────────────────────────────────
EOF
