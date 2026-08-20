-- ═══════════════════════════════════════════════════════════════════════════
-- CLEAN SLATE — wipe all RUNTIME / team data for a fresh start.
-- Removes everything that populates the faculty dashboard + debrief (teams, runs,
-- participants, submissions, construct scores, decisions, faculty action log,
-- round state, board calls, broadcasts). KEEPS all simulation CONTENT so the sim
-- still works: simulations, rounds, artifacts, decisions/options, answer keys,
-- wiki, roles, catalogue.  Requested by the user; irreversible.
-- ═══════════════════════════════════════════════════════════════════════════
BEGIN;
TRUNCATE
  sim2_submissions,
  sim2_construct_scores,
  sim2_round_state,
  sim2_board_call,
  sim2_broadcast,
  decision_events,
  run_participants,
  run_round_clock,
  run_round_bypass,
  run_artifact_overrides,
  run_injected_artifacts,
  run_construct_state,
  sim1_round_state,
  faculty_actions,
  participant_results,
  team_results,
  simulation_runs,
  participant,
  team
  RESTART IDENTITY CASCADE;
COMMIT;
