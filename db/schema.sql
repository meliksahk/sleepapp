\restrict dbmate

-- Dumped from database version 16.14
-- Dumped by pg_dump version 18.4

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
-- Name: content_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.content_status AS ENUM (
    'draft',
    'scheduled',
    'published'
);


--
-- Name: ott_purpose; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ott_purpose AS ENUM (
    'magic_link',
    'email_verify',
    'password_reset'
);


--
-- Name: user_kind; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_kind AS ENUM (
    'anonymous',
    'registered',
    'admin'
);


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: archetype_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.archetype_results (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    archetype_slug text NOT NULL,
    answers jsonb NOT NULL,
    scores jsonb NOT NULL,
    version integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: auth_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.auth_devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_fingerprint text NOT NULL,
    platform text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: feature_flags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feature_flags (
    key text NOT NULL,
    description text,
    rules jsonb DEFAULT '{"enabled": false}'::jsonb NOT NULL,
    updated_by uuid,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: one_time_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.one_time_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    purpose public.ott_purpose NOT NULL,
    token_hash text NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    used_at timestamp with time zone
);


--
-- Name: presets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.presets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    soundscape_id uuid NOT NULL,
    archetype_slug text NOT NULL,
    mixer_state jsonb NOT NULL
);


--
-- Name: profiles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    display_name text,
    chronotype text,
    locale text DEFAULT 'en'::text NOT NULL,
    timezone text DEFAULT 'UTC'::text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: refresh_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.refresh_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    token_hash text NOT NULL,
    family_id uuid NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: soundscapes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.soundscapes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slug text NOT NULL,
    title_i18n jsonb NOT NULL,
    engine_params jsonb NOT NULL,
    layer_defs jsonb NOT NULL,
    archetype_affinity text[] DEFAULT '{}'::text[] NOT NULL,
    status public.content_status DEFAULT 'draft'::public.content_status NOT NULL,
    publish_at timestamp with time zone,
    created_by uuid,
    version integer DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    kind public.user_kind DEFAULT 'anonymous'::public.user_kind NOT NULL,
    email text,
    email_verified_at timestamp with time zone,
    password_hash text,
    totp_secret text,
    roles text[] DEFAULT '{}'::text[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: web_archetype_results; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.web_archetype_results (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    share_slug text NOT NULL,
    archetype_slug text NOT NULL,
    scores jsonb NOT NULL,
    version integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: archetype_results archetype_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.archetype_results
    ADD CONSTRAINT archetype_results_pkey PRIMARY KEY (id);


--
-- Name: auth_devices auth_devices_device_fingerprint_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_devices
    ADD CONSTRAINT auth_devices_device_fingerprint_key UNIQUE (device_fingerprint);


--
-- Name: auth_devices auth_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_devices
    ADD CONSTRAINT auth_devices_pkey PRIMARY KEY (id);


--
-- Name: feature_flags feature_flags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feature_flags
    ADD CONSTRAINT feature_flags_pkey PRIMARY KEY (key);


--
-- Name: one_time_tokens one_time_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.one_time_tokens
    ADD CONSTRAINT one_time_tokens_pkey PRIMARY KEY (id);


--
-- Name: one_time_tokens one_time_tokens_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.one_time_tokens
    ADD CONSTRAINT one_time_tokens_token_hash_key UNIQUE (token_hash);


--
-- Name: presets presets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.presets
    ADD CONSTRAINT presets_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_pkey PRIMARY KEY (id);


--
-- Name: refresh_tokens refresh_tokens_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_token_hash_key UNIQUE (token_hash);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: soundscapes soundscapes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.soundscapes
    ADD CONSTRAINT soundscapes_pkey PRIMARY KEY (id);


--
-- Name: soundscapes soundscapes_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.soundscapes
    ADD CONSTRAINT soundscapes_slug_key UNIQUE (slug);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: web_archetype_results web_archetype_results_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_archetype_results
    ADD CONSTRAINT web_archetype_results_pkey PRIMARY KEY (id);


--
-- Name: web_archetype_results web_archetype_results_share_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.web_archetype_results
    ADD CONSTRAINT web_archetype_results_share_slug_key UNIQUE (share_slug);


--
-- Name: idx_archetype_results_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_archetype_results_user ON public.archetype_results USING btree (user_id, created_at DESC);


--
-- Name: idx_auth_devices_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_auth_devices_user ON public.auth_devices USING btree (user_id);


--
-- Name: idx_ott_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ott_user ON public.one_time_tokens USING btree (user_id);


--
-- Name: idx_presets_soundscape; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_presets_soundscape ON public.presets USING btree (soundscape_id);


--
-- Name: idx_refresh_tokens_family; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refresh_tokens_family ON public.refresh_tokens USING btree (family_id);


--
-- Name: idx_refresh_tokens_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_refresh_tokens_user ON public.refresh_tokens USING btree (user_id);


--
-- Name: idx_soundscapes_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_soundscapes_status ON public.soundscapes USING btree (status);


--
-- Name: archetype_results archetype_results_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.archetype_results
    ADD CONSTRAINT archetype_results_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: auth_devices auth_devices_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.auth_devices
    ADD CONSTRAINT auth_devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: one_time_tokens one_time_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.one_time_tokens
    ADD CONSTRAINT one_time_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: presets presets_soundscape_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.presets
    ADD CONSTRAINT presets_soundscape_id_fkey FOREIGN KEY (soundscape_id) REFERENCES public.soundscapes(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: refresh_tokens refresh_tokens_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.refresh_tokens
    ADD CONSTRAINT refresh_tokens_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict dbmate


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20260715120001'),
    ('20260715120002'),
    ('20260715120003'),
    ('20260715120004'),
    ('20260715120005');
