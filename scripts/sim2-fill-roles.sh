#!/usr/bin/env bash
# ============================================================================
# Sim 2 — fill the unclaimed roles on an EXISTING team with bots.
#
# Use this when you have already created a team in the browser and are stuck on
# "waiting for N more". Unlike sim2-dev-team.sh (which creates its own team),
# this joins bots to the team you are already sitting in.
#
#   ./sim2-fill-roles.sh                 # auto-detects your incomplete team
#   ./sim2-fill-roles.sh <teamId>        # or name it explicitly
#
# Afterwards the waiting page flips to "Start Round 1" on its own (it polls).
# ============================================================================
set -euo pipefail

API=${API:-http://localhost:8080}
SIM2=5116d200-0000-4000-a000-000000000002
PSQL="psql -h 127.0.0.1 -U postgres -d simulator_db -q -t -A"

TEAM=${1:-}

if [ -z "$TEAM" ]; then
  TEAM=$($PSQL -c "SELECT t.team_id FROM team t
                   LEFT JOIN participant p ON p.team_id = t.team_id
                   WHERE t.simulation_id = '$SIM2'
                   GROUP BY t.team_id
                   HAVING count(p.participant_id) < 6
                   ORDER BY count(p.participant_id) DESC
                   LIMIT 1;")
  [ -z "$TEAM" ] && { echo "No incomplete Meridian team found. Pass a teamId explicitly."; exit 1; }
  echo "Auto-detected team: $TEAM"
fi

# Which roles are still free on this team?
TAKEN=$(curl -s "$API/api/teams/$TEAM/roles")

for ROLE in DATA_QUALITY_ANALYST CATEGORY_REGIONAL_ANALYST REPORTING_DASHBOARD_ANALYST \
            PEOPLE_ANALYTICS_ASSOCIATE AUTOMATION_BI_ASSOCIATE TEAM_LEAD; do
  # skip roles that already have an occupant (any non-null value after the key)
  if grep -q "\"$ROLE\":\"" <<<"$TAKEN"; then
    echo "  $ROLE already taken — skipping"
    continue
  fi
  PJ=$(curl -s -X POST "$API/api/teams/$TEAM/join" -H 'Content-Type: application/json' \
        -d "{\"participantName\":\"bot-$ROLE\"}")
  PID=$(sed -E 's/.*"participantId":"([^"]+)".*/\1/' <<<"$PJ")
  CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST "$API/api/teams/$TEAM/assign-role" \
    -H 'Content-Type: application/json' \
    -d "{\"participantId\":\"$PID\",\"role\":\"$ROLE\"}")
  echo "  filled $ROLE (HTTP $CODE)  participantId=$PID"
done

echo
echo "Done. Your waiting page should now show 6/6 and enable 'Start Round 1'."
echo "teamId=$TEAM"
