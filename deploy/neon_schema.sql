--
-- PostgreSQL database dump
--

\restrict bvzP2uPtLsi6ch0L8cDgRq1qKmvSopdKszpQ4GEvrYCoo4mbJafhpcjjGgE2JlC

-- Dumped from database version 18.2
-- Dumped by pg_dump version 18.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: uuid-ossp; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;


--
-- Name: EXTENSION "uuid-ossp"; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION "uuid-ossp" IS 'generate universally unique identifiers (UUIDs)';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: artifact_conditions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artifact_conditions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    artifact_id uuid NOT NULL,
    depends_on_decision_id uuid NOT NULL,
    expected_action character varying(100) NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);


--
-- Name: artifacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.artifacts (
    artifact_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    round_id uuid NOT NULL,
    artifact_type text NOT NULL,
    open_offset_min integer NOT NULL,
    expiry_offset_min integer NOT NULL,
    expected_action boolean DEFAULT false NOT NULL,
    payload jsonb NOT NULL,
    allowed_roles jsonb
);


--
-- Name: catalogue_artifacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.catalogue_artifacts (
    catalogue_id uuid DEFAULT gen_random_uuid() NOT NULL,
    simulation_id uuid NOT NULL,
    round_number integer NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    tier text NOT NULL,
    canonical_answer text,
    effect text,
    CONSTRAINT catalogue_artifacts_tier_check CHECK ((tier = ANY (ARRAY['CONTEXT'::text, 'SCORED'::text]))),
    CONSTRAINT ck_catalogue_scored_needs_answer CHECK (((tier = 'CONTEXT'::text) OR (canonical_answer IS NOT NULL)))
);


--
-- Name: decision_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.decision_events (
    decision_event_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    run_id uuid NOT NULL,
    run_participant_id uuid NOT NULL,
    artifact_id uuid NOT NULL,
    decision_id uuid NOT NULL,
    action text NOT NULL,
    decision_type text NOT NULL,
    latency_band text NOT NULL,
    decided_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT decision_events_decision_type_check CHECK ((decision_type = ANY (ARRAY['EXPLICIT'::text, 'IMPLICIT'::text]))),
    CONSTRAINT decision_events_latency_band_check CHECK ((latency_band = ANY (ARRAY['EARLY'::text, 'MODERATE'::text, 'DELAYED'::text])))
);


--
-- Name: decision_options; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.decision_options (
    option_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    decision_id uuid NOT NULL,
    action text NOT NULL,
    trust_delta integer NOT NULL,
    risk_delta integer NOT NULL,
    ethics_delta integer NOT NULL,
    execution_delta integer NOT NULL
);


--
-- Name: decisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.decisions (
    decision_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    artifact_id uuid NOT NULL,
    decision_type text NOT NULL,
    is_final boolean DEFAULT false NOT NULL,
    options jsonb NOT NULL,
    allowed_roles jsonb NOT NULL,
    CONSTRAINT decisions_decision_type_check CHECK ((decision_type = ANY (ARRAY['EXPLICIT'::text, 'IMPLICIT'::text])))
);


--
-- Name: faculty_actions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.faculty_actions (
    action_id uuid DEFAULT gen_random_uuid() NOT NULL,
    simulation_id uuid,
    run_id uuid,
    team_id uuid,
    round_number integer,
    action_type text NOT NULL,
    scope text NOT NULL,
    target_artifact uuid,
    delay_minutes integer,
    injected_content jsonb,
    note text,
    created_by text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT faculty_actions_action_type_check CHECK ((action_type = ANY (ARRAY['PAUSE'::text, 'RESUME'::text, 'DELAY'::text, 'BYPASS'::text, 'INJECT'::text, 'OVERRIDE'::text]))),
    CONSTRAINT faculty_actions_scope_check CHECK ((scope = ANY (ARRAY['ALL'::text, 'TEAM'::text])))
);


--
-- Name: participant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.participant (
    participant_id uuid NOT NULL,
    name character varying(255),
    role character varying(255),
    team_id uuid
);


--
-- Name: participant_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.participant_results (
    participant_result_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    run_participant_id uuid NOT NULL,
    round_number integer NOT NULL,
    constructs jsonb NOT NULL,
    banding jsonb NOT NULL,
    calculated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: rounds; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rounds (
    round_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    simulation_id uuid NOT NULL,
    round_number integer NOT NULL,
    duration_minutes integer NOT NULL
);


--
-- Name: run_artifact_overrides; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.run_artifact_overrides (
    run_id uuid NOT NULL,
    artifact_id uuid NOT NULL,
    delay_minutes integer DEFAULT 0 NOT NULL,
    bypassed boolean DEFAULT false NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: run_construct_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.run_construct_state (
    run_id uuid NOT NULL,
    construct_name text NOT NULL,
    value integer NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    run_participant_id uuid NOT NULL,
    CONSTRAINT run_construct_state_value_check CHECK (((value >= 0) AND (value <= 100)))
);


--
-- Name: run_injected_artifacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.run_injected_artifacts (
    injection_id uuid DEFAULT gen_random_uuid() NOT NULL,
    run_id uuid NOT NULL,
    round_number integer NOT NULL,
    catalogue_id uuid,
    title text NOT NULL,
    content text NOT NULL,
    tier text NOT NULL,
    scored boolean DEFAULT false NOT NULL,
    canonical_answer text,
    injected_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_injected_scored_needs_answer CHECK (((scored = false) OR (canonical_answer IS NOT NULL))),
    CONSTRAINT run_injected_artifacts_tier_check CHECK ((tier = ANY (ARRAY['CATALOGUE'::text, 'ON_THE_FLY'::text])))
);


--
-- Name: run_participants; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.run_participants (
    run_participant_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    run_id uuid NOT NULL,
    user_id uuid,
    role text NOT NULL,
    can_submit_final boolean DEFAULT false NOT NULL,
    joined_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: run_round_bypass; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.run_round_bypass (
    run_id uuid NOT NULL,
    round_number integer NOT NULL,
    reason text,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: run_round_clock; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.run_round_clock (
    run_id uuid NOT NULL,
    round_number integer DEFAULT 0 NOT NULL,
    paused_seconds_total integer DEFAULT 0 NOT NULL,
    paused_at timestamp without time zone,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT run_round_clock_paused_seconds_total_check CHECK ((paused_seconds_total >= 0))
);


--
-- Name: sim2_answer_key; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sim2_answer_key (
    simulation_id uuid NOT NULL,
    round_number integer NOT NULL,
    question text NOT NULL,
    canonical_answer text NOT NULL,
    answer_type text NOT NULL,
    tolerance_abs numeric,
    tolerance_pct numeric,
    grading_notes text,
    CONSTRAINT sim2_answer_key_answer_type_check CHECK ((answer_type = ANY (ARRAY['NUMERIC'::text, 'TEXT'::text, 'CHOICE'::text, 'FREE_TEXT'::text])))
);


--
-- Name: sim2_construct_scores; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sim2_construct_scores (
    run_id uuid NOT NULL,
    round_number integer NOT NULL,
    construct_name text NOT NULL,
    value integer,
    status text DEFAULT 'SCORED'::text NOT NULL,
    detail text,
    calculated_at timestamp without time zone DEFAULT now() NOT NULL,
    original_value integer,
    overridden_by text,
    override_reason text,
    overridden_at timestamp without time zone,
    CONSTRAINT ck_sim2_value_present CHECK ((((status = 'SCORED'::text) AND (value IS NOT NULL)) OR ((status = ANY (ARRAY['NOT_YET_SCORED'::text, 'NOT_APPLICABLE'::text])) AND (value IS NULL)))),
    CONSTRAINT sim2_construct_scores_construct_name_check CHECK ((construct_name = ANY (ARRAY['DATA_TRUST_SCORE'::text, 'ANALYTICAL_RIGOR'::text, 'INSIGHT_COMMUNICATION'::text, 'JUDGMENT_CALIBRATION'::text, 'TURNAROUND_DISCIPLINE'::text]))),
    CONSTRAINT sim2_construct_scores_status_check CHECK ((status = ANY (ARRAY['SCORED'::text, 'NOT_YET_SCORED'::text, 'NOT_APPLICABLE'::text]))),
    CONSTRAINT sim2_construct_scores_value_check CHECK (((value >= 0) AND (value <= 100)))
);


--
-- Name: sim2_round_state; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sim2_round_state (
    run_id uuid NOT NULL,
    round_number integer NOT NULL,
    status text DEFAULT 'PENDING'::text NOT NULL,
    started_at timestamp without time zone,
    ends_at timestamp without time zone,
    completed_at timestamp without time zone,
    CONSTRAINT sim2_round_state_status_check CHECK ((status = ANY (ARRAY['PENDING'::text, 'ACTIVE'::text, 'COMPLETE'::text, 'BYPASSED'::text])))
);


--
-- Name: sim2_submissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sim2_submissions (
    submission_id uuid DEFAULT gen_random_uuid() NOT NULL,
    run_id uuid NOT NULL,
    round_number integer NOT NULL,
    submitted_by uuid NOT NULL,
    file_path text,
    original_filename text,
    typed_answer text NOT NULL,
    confidence text NOT NULL,
    submitted_at timestamp without time zone DEFAULT now() NOT NULL,
    active_seconds_used integer,
    is_correct boolean,
    score_detail jsonb,
    CONSTRAINT sim2_submissions_confidence_check CHECK ((confidence = ANY (ARRAY['HIGH'::text, 'MEDIUM'::text, 'LOW'::text])))
);


--
-- Name: sim2_wiki_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sim2_wiki_entries (
    entry_id uuid DEFAULT gen_random_uuid() NOT NULL,
    simulation_id uuid NOT NULL,
    section text NOT NULL,
    round_number integer,
    title text NOT NULL,
    body text NOT NULL,
    ordinal integer DEFAULT 0 NOT NULL,
    editable boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT sim2_wiki_entries_section_check CHECK ((section = ANY (ARRAY['FUNCTIONS'::text, 'FACTS'::text, 'FAQ'::text])))
);


--
-- Name: simulation_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.simulation_roles (
    simulation_id uuid NOT NULL,
    role_code text NOT NULL,
    display_name text NOT NULL,
    ordinal integer NOT NULL,
    is_lead boolean DEFAULT false NOT NULL
);


--
-- Name: simulation_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.simulation_runs (
    run_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    simulation_id uuid NOT NULL,
    team_name text NOT NULL,
    started_at timestamp without time zone DEFAULT now() NOT NULL,
    status text NOT NULL,
    team_id uuid,
    CONSTRAINT simulation_runs_status_check CHECK ((status = ANY (ARRAY['ACTIVE'::text, 'COMPLETED'::text])))
);


--
-- Name: simulations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.simulations (
    simulation_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    name text NOT NULL,
    description text,
    total_rounds integer NOT NULL,
    duration_minutes integer NOT NULL
);


--
-- Name: team; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team (
    team_id uuid NOT NULL,
    locked boolean NOT NULL,
    team_name character varying(255),
    simulation_id uuid
);


--
-- Name: team_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_results (
    team_result_id uuid DEFAULT public.uuid_generate_v4() NOT NULL,
    run_id uuid NOT NULL,
    round_number integer NOT NULL,
    constructs jsonb NOT NULL,
    dominant_pattern text NOT NULL,
    calculated_at timestamp without time zone DEFAULT now() NOT NULL
);


--
-- Name: v_round_decision_events; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_round_decision_events AS
 SELECT de.decision_event_id,
    de.run_id,
    de.run_participant_id,
    rp.role AS participant_role,
    r.round_number,
    a.artifact_id,
    a.artifact_type,
    a.expected_action,
    d.decision_id,
    d.decision_type,
    d.is_final,
    de.action,
    de.latency_band,
    de.decided_at
   FROM ((((public.decision_events de
     JOIN public.run_participants rp ON ((rp.run_participant_id = de.run_participant_id)))
     JOIN public.decisions d ON ((d.decision_id = de.decision_id)))
     JOIN public.artifacts a ON ((a.artifact_id = d.artifact_id)))
     JOIN public.rounds r ON ((r.round_id = a.round_id)));


--
-- Name: artifact_conditions artifact_conditions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifact_conditions
    ADD CONSTRAINT artifact_conditions_pkey PRIMARY KEY (id);


--
-- Name: artifacts artifacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifacts
    ADD CONSTRAINT artifacts_pkey PRIMARY KEY (artifact_id);


--
-- Name: catalogue_artifacts catalogue_artifacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.catalogue_artifacts
    ADD CONSTRAINT catalogue_artifacts_pkey PRIMARY KEY (catalogue_id);


--
-- Name: decision_events decision_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_events
    ADD CONSTRAINT decision_events_pkey PRIMARY KEY (decision_event_id);


--
-- Name: decision_options decision_options_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_options
    ADD CONSTRAINT decision_options_pkey PRIMARY KEY (option_id);


--
-- Name: decisions decisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decisions
    ADD CONSTRAINT decisions_pkey PRIMARY KEY (decision_id);


--
-- Name: faculty_actions faculty_actions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.faculty_actions
    ADD CONSTRAINT faculty_actions_pkey PRIMARY KEY (action_id);


--
-- Name: participant participant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participant
    ADD CONSTRAINT participant_pkey PRIMARY KEY (participant_id);


--
-- Name: participant_results participant_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participant_results
    ADD CONSTRAINT participant_results_pkey PRIMARY KEY (participant_result_id);


--
-- Name: run_artifact_overrides pk_run_artifact_overrides; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run_artifact_overrides
    ADD CONSTRAINT pk_run_artifact_overrides PRIMARY KEY (run_id, artifact_id);


--
-- Name: run_round_bypass pk_run_round_bypass; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run_round_bypass
    ADD CONSTRAINT pk_run_round_bypass PRIMARY KEY (run_id, round_number);


--
-- Name: run_round_clock pk_run_round_clock; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run_round_clock
    ADD CONSTRAINT pk_run_round_clock PRIMARY KEY (run_id, round_number);


--
-- Name: sim2_answer_key pk_sim2_answer_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sim2_answer_key
    ADD CONSTRAINT pk_sim2_answer_key PRIMARY KEY (simulation_id, round_number);


--
-- Name: sim2_construct_scores pk_sim2_construct_scores; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sim2_construct_scores
    ADD CONSTRAINT pk_sim2_construct_scores PRIMARY KEY (run_id, round_number, construct_name);


--
-- Name: sim2_round_state pk_sim2_round_state; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sim2_round_state
    ADD CONSTRAINT pk_sim2_round_state PRIMARY KEY (run_id, round_number);


--
-- Name: simulation_roles pk_simulation_roles; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.simulation_roles
    ADD CONSTRAINT pk_simulation_roles PRIMARY KEY (simulation_id, role_code);


--
-- Name: rounds rounds_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rounds
    ADD CONSTRAINT rounds_pkey PRIMARY KEY (round_id);


--
-- Name: run_construct_state run_construct_state_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run_construct_state
    ADD CONSTRAINT run_construct_state_pkey PRIMARY KEY (run_id, run_participant_id, construct_name);


--
-- Name: run_injected_artifacts run_injected_artifacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run_injected_artifacts
    ADD CONSTRAINT run_injected_artifacts_pkey PRIMARY KEY (injection_id);


--
-- Name: run_participants run_participants_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run_participants
    ADD CONSTRAINT run_participants_pkey PRIMARY KEY (run_participant_id);


--
-- Name: sim2_submissions sim2_submissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sim2_submissions
    ADD CONSTRAINT sim2_submissions_pkey PRIMARY KEY (submission_id);


--
-- Name: sim2_wiki_entries sim2_wiki_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sim2_wiki_entries
    ADD CONSTRAINT sim2_wiki_entries_pkey PRIMARY KEY (entry_id);


--
-- Name: simulation_runs simulation_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.simulation_runs
    ADD CONSTRAINT simulation_runs_pkey PRIMARY KEY (run_id);


--
-- Name: simulations simulations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.simulations
    ADD CONSTRAINT simulations_pkey PRIMARY KEY (simulation_id);


--
-- Name: team team_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team
    ADD CONSTRAINT team_pkey PRIMARY KEY (team_id);


--
-- Name: team_results team_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_results
    ADD CONSTRAINT team_results_pkey PRIMARY KEY (team_result_id);


--
-- Name: decision_events unique_decision_per_participant; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_events
    ADD CONSTRAINT unique_decision_per_participant UNIQUE (run_id, run_participant_id, decision_id);


--
-- Name: decision_options uq_decision_action; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_options
    ADD CONSTRAINT uq_decision_action UNIQUE (decision_id, action);


--
-- Name: run_participants uq_run_role; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run_participants
    ADD CONSTRAINT uq_run_role UNIQUE (run_id, role);


--
-- Name: sim2_submissions uq_sim2_submission_round; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sim2_submissions
    ADD CONSTRAINT uq_sim2_submission_round UNIQUE (run_id, round_number);


--
-- Name: rounds uq_simulation_round; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rounds
    ADD CONSTRAINT uq_simulation_round UNIQUE (simulation_id, round_number);


--
-- Name: idx_faculty_actions_run; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_faculty_actions_run ON public.faculty_actions USING btree (run_id, created_at DESC);


--
-- Name: idx_sim2_wiki_sim; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_sim2_wiki_sim ON public.sim2_wiki_entries USING btree (simulation_id, section, round_number, ordinal);


--
-- Name: idx_simulation_roles_sim_ordinal; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_simulation_roles_sim_ordinal ON public.simulation_roles USING btree (simulation_id, ordinal);


--
-- Name: idx_team_simulation; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_team_simulation ON public.team USING btree (simulation_id);


--
-- Name: unique_team_run; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX unique_team_run ON public.simulation_runs USING btree (team_id);


--
-- Name: uq_construct_per_participant; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_construct_per_participant ON public.run_construct_state USING btree (run_id, run_participant_id, construct_name);


--
-- Name: uq_simulation_roles_one_lead; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_simulation_roles_one_lead ON public.simulation_roles USING btree (simulation_id) WHERE is_lead;


--
-- Name: decision_options decision_options_decision_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_options
    ADD CONSTRAINT decision_options_decision_id_fkey FOREIGN KEY (decision_id) REFERENCES public.decisions(decision_id);


--
-- Name: artifacts fk_artifact_round; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.artifacts
    ADD CONSTRAINT fk_artifact_round FOREIGN KEY (round_id) REFERENCES public.rounds(round_id) ON DELETE CASCADE;


--
-- Name: decisions fk_decision_artifact; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decisions
    ADD CONSTRAINT fk_decision_artifact FOREIGN KEY (artifact_id) REFERENCES public.artifacts(artifact_id) ON DELETE CASCADE;


--
-- Name: decision_events fk_event_artifact; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_events
    ADD CONSTRAINT fk_event_artifact FOREIGN KEY (artifact_id) REFERENCES public.artifacts(artifact_id);


--
-- Name: decision_events fk_event_decision; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_events
    ADD CONSTRAINT fk_event_decision FOREIGN KEY (decision_id) REFERENCES public.decisions(decision_id);


--
-- Name: decision_events fk_event_participant; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_events
    ADD CONSTRAINT fk_event_participant FOREIGN KEY (run_participant_id) REFERENCES public.run_participants(run_participant_id) ON DELETE CASCADE;


--
-- Name: decision_events fk_event_run; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.decision_events
    ADD CONSTRAINT fk_event_run FOREIGN KEY (run_id) REFERENCES public.simulation_runs(run_id) ON DELETE CASCADE;


--
-- Name: run_participants fk_participant_run; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run_participants
    ADD CONSTRAINT fk_participant_run FOREIGN KEY (run_id) REFERENCES public.simulation_runs(run_id) ON DELETE CASCADE;


--
-- Name: participant_results fk_result_participant; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.participant_results
    ADD CONSTRAINT fk_result_participant FOREIGN KEY (run_participant_id) REFERENCES public.run_participants(run_participant_id) ON DELETE CASCADE;


--
-- Name: rounds fk_round_simulation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rounds
    ADD CONSTRAINT fk_round_simulation FOREIGN KEY (simulation_id) REFERENCES public.simulations(simulation_id) ON DELETE CASCADE;


--
-- Name: simulation_runs fk_run_simulation; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.simulation_runs
    ADD CONSTRAINT fk_run_simulation FOREIGN KEY (simulation_id) REFERENCES public.simulations(simulation_id);


--
-- Name: sim2_construct_scores fk_sim2_construct_run; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sim2_construct_scores
    ADD CONSTRAINT fk_sim2_construct_run FOREIGN KEY (run_id) REFERENCES public.simulation_runs(run_id) ON DELETE CASCADE;


--
-- Name: sim2_round_state fk_sim2_round_state_run; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sim2_round_state
    ADD CONSTRAINT fk_sim2_round_state_run FOREIGN KEY (run_id) REFERENCES public.simulation_runs(run_id) ON DELETE CASCADE;


--
-- Name: sim2_submissions fk_sim2_submission_run; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sim2_submissions
    ADD CONSTRAINT fk_sim2_submission_run FOREIGN KEY (run_id) REFERENCES public.simulation_runs(run_id) ON DELETE CASCADE;


--
-- Name: team_results fk_team_result_run; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_results
    ADD CONSTRAINT fk_team_result_run FOREIGN KEY (run_id) REFERENCES public.simulation_runs(run_id) ON DELETE CASCADE;


--
-- Name: run_construct_state run_construct_state_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.run_construct_state
    ADD CONSTRAINT run_construct_state_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.simulation_runs(run_id);


--
-- PostgreSQL database dump complete
--

\unrestrict bvzP2uPtLsi6ch0L8cDgRq1qKmvSopdKszpQ4GEvrYCoo4mbJafhpcjjGgE2JlC

