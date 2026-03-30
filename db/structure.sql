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
-- Name: ogr_system_tables; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA ogr_system_tables;


--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS '';


--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: postgis_sfcgal; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis_sfcgal WITH SCHEMA public;


--
-- Name: EXTENSION postgis_sfcgal; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION postgis_sfcgal IS 'PostGIS SFCGAL functions';


--
-- Name: event_trigger_function_for_metadata(); Type: FUNCTION; Schema: ogr_system_tables; Owner: -
--

CREATE FUNCTION ogr_system_tables.event_trigger_function_for_metadata() RETURNS event_trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    obj record;
BEGIN
  IF has_schema_privilege('ogr_system_tables', 'USAGE') THEN
   IF has_table_privilege('ogr_system_tables.metadata', 'DELETE') THEN
    FOR obj IN SELECT * FROM pg_event_trigger_dropped_objects()
    LOOP
        IF obj.object_type = 'table' THEN
            DELETE FROM ogr_system_tables.metadata m WHERE m.schema_name = obj.schema_name AND m.table_name = obj.object_name;
        END IF;
    END LOOP;
   END IF;
  END IF;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: metadata; Type: TABLE; Schema: ogr_system_tables; Owner: -
--

CREATE TABLE ogr_system_tables.metadata (
    id integer NOT NULL,
    schema_name text NOT NULL,
    table_name text NOT NULL,
    metadata text
);


--
-- Name: metadata_id_seq; Type: SEQUENCE; Schema: ogr_system_tables; Owner: -
--

CREATE SEQUENCE ogr_system_tables.metadata_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: metadata_id_seq; Type: SEQUENCE OWNED BY; Schema: ogr_system_tables; Owner: -
--

ALTER SEQUENCE ogr_system_tables.metadata_id_seq OWNED BY ogr_system_tables.metadata.id;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: buildings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.buildings (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    dataset_id bigint NOT NULL,
    name character varying,
    height numeric(10,2) DEFAULT 28.0 NOT NULL,
    base_height numeric(10,2) DEFAULT 0.0 NOT NULL,
    geom public.geometry(MultiPolygonZ,4326) NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: buildings_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.buildings_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: buildings_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.buildings_id_seq OWNED BY public.buildings.id;


--
-- Name: datasets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.datasets (
    id bigint NOT NULL,
    status character varying DEFAULT 'uploaded'::character varying,
    data_type character varying NOT NULL,
    project_id bigint NOT NULL,
    info jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: datasets_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.datasets_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: datasets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.datasets_id_seq OWNED BY public.datasets.id;


--
-- Name: layer_artifacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.layer_artifacts (
    id bigint NOT NULL,
    map_layer_id bigint NOT NULL,
    format character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    storage_path character varying NOT NULL,
    public_url character varying,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    error_message text,
    active boolean DEFAULT false NOT NULL,
    generated_at timestamp(6) without time zone,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: layer_artifacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.layer_artifacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: layer_artifacts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.layer_artifacts_id_seq OWNED BY public.layer_artifacts.id;


--
-- Name: map_layers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.map_layers (
    id bigint NOT NULL,
    project_id bigint NOT NULL,
    dataset_id bigint NOT NULL,
    name character varying NOT NULL,
    layer_type character varying NOT NULL,
    source character varying NOT NULL,
    status character varying DEFAULT 'pending'::character varying NOT NULL,
    visible boolean DEFAULT true NOT NULL,
    last_processed_at timestamp(6) without time zone,
    last_error text,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: map_layers_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.map_layers_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: map_layers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.map_layers_id_seq OWNED BY public.map_layers.id;


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id bigint NOT NULL,
    name character varying NOT NULL,
    location character varying,
    description text,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: projects_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.projects_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: projects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.projects_id_seq OWNED BY public.projects.id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: metadata id; Type: DEFAULT; Schema: ogr_system_tables; Owner: -
--

ALTER TABLE ONLY ogr_system_tables.metadata ALTER COLUMN id SET DEFAULT nextval('ogr_system_tables.metadata_id_seq'::regclass);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: buildings id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.buildings ALTER COLUMN id SET DEFAULT nextval('public.buildings_id_seq'::regclass);


--
-- Name: datasets id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datasets ALTER COLUMN id SET DEFAULT nextval('public.datasets_id_seq'::regclass);


--
-- Name: layer_artifacts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.layer_artifacts ALTER COLUMN id SET DEFAULT nextval('public.layer_artifacts_id_seq'::regclass);


--
-- Name: map_layers id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_layers ALTER COLUMN id SET DEFAULT nextval('public.map_layers_id_seq'::regclass);


--
-- Name: projects id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects ALTER COLUMN id SET DEFAULT nextval('public.projects_id_seq'::regclass);


--
-- Name: metadata metadata_schema_name_table_name_key; Type: CONSTRAINT; Schema: ogr_system_tables; Owner: -
--

ALTER TABLE ONLY ogr_system_tables.metadata
    ADD CONSTRAINT metadata_schema_name_table_name_key UNIQUE (schema_name, table_name);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: buildings buildings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.buildings
    ADD CONSTRAINT buildings_pkey PRIMARY KEY (id);


--
-- Name: datasets datasets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datasets
    ADD CONSTRAINT datasets_pkey PRIMARY KEY (id);


--
-- Name: layer_artifacts layer_artifacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.layer_artifacts
    ADD CONSTRAINT layer_artifacts_pkey PRIMARY KEY (id);


--
-- Name: map_layers map_layers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_layers
    ADD CONSTRAINT map_layers_pkey PRIMARY KEY (id);


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_buildings_on_dataset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_buildings_on_dataset_id ON public.buildings USING btree (dataset_id);


--
-- Name: index_buildings_on_geom; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_buildings_on_geom ON public.buildings USING gist (geom);


--
-- Name: index_buildings_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_buildings_on_project_id ON public.buildings USING btree (project_id);


--
-- Name: index_datasets_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_datasets_on_project_id ON public.datasets USING btree (project_id);


--
-- Name: index_datasets_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_datasets_on_status ON public.datasets USING btree (status);


--
-- Name: index_layer_artifacts_active_per_format; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_layer_artifacts_active_per_format ON public.layer_artifacts USING btree (map_layer_id, format, active) WHERE (active = true);


--
-- Name: index_layer_artifacts_on_map_layer_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_layer_artifacts_on_map_layer_id ON public.layer_artifacts USING btree (map_layer_id);


--
-- Name: index_layer_artifacts_on_map_layer_id_and_format_and_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_layer_artifacts_on_map_layer_id_and_format_and_status ON public.layer_artifacts USING btree (map_layer_id, format, status);


--
-- Name: index_map_layers_on_dataset_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_map_layers_on_dataset_id ON public.map_layers USING btree (dataset_id);


--
-- Name: index_map_layers_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_map_layers_on_project_id ON public.map_layers USING btree (project_id);


--
-- Name: index_map_layers_on_project_id_and_sort_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_map_layers_on_project_id_and_sort_order ON public.map_layers USING btree (project_id, sort_order);


--
-- Name: index_map_layers_on_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_map_layers_on_status ON public.map_layers USING btree (status);


--
-- Name: map_layers fk_rails_04e4a6f46d; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_layers
    ADD CONSTRAINT fk_rails_04e4a6f46d FOREIGN KEY (dataset_id) REFERENCES public.datasets(id) ON DELETE CASCADE;


--
-- Name: layer_artifacts fk_rails_2127d4125a; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.layer_artifacts
    ADD CONSTRAINT fk_rails_2127d4125a FOREIGN KEY (map_layer_id) REFERENCES public.map_layers(id) ON DELETE CASCADE;


--
-- Name: datasets fk_rails_3c9ca87db2; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.datasets
    ADD CONSTRAINT fk_rails_3c9ca87db2 FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: buildings fk_rails_48c8763d4f; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.buildings
    ADD CONSTRAINT fk_rails_48c8763d4f FOREIGN KEY (dataset_id) REFERENCES public.datasets(id) ON DELETE CASCADE;


--
-- Name: map_layers fk_rails_8485c588a0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.map_layers
    ADD CONSTRAINT fk_rails_8485c588a0 FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: buildings fk_rails_e6f7f8c2d9; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.buildings
    ADD CONSTRAINT fk_rails_e6f7f8c2d9 FOREIGN KEY (project_id) REFERENCES public.projects(id) ON DELETE CASCADE;


--
-- Name: ogr_system_tables_event_trigger_for_metadata; Type: EVENT TRIGGER; Schema: -; Owner: -
--

CREATE EVENT TRIGGER ogr_system_tables_event_trigger_for_metadata ON sql_drop
   EXECUTE FUNCTION ogr_system_tables.event_trigger_function_for_metadata();


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260330113000'),
('20260330100000'),
('20260320110100'),
('20260320110000'),
('20260318110100'),
('20260318110000'),
('20260316110744'),
('20260316110627'),
('20260315131639');

