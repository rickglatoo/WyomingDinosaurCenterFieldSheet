-- ============================================================
-- Wyoming Dinosaur Center — Collections Database Schema
-- Darwin Core aligned + PaleoContext + custom field extensions
--
-- Naming convention:
--   [DwC]      = standard Darwin Core term (snake_case of camelCase term)
--   [PaleoCtx] = Darwin Core PaleoContext extension
--   [WDC]      = WDC custom field, no DwC equivalent
--
-- Table names follow DwC class names:
--   locations  → DwC Location class
--   occurrences → DwC Occurrence class (specimens)
--
-- Paste into Supabase → SQL Editor → Run
-- ============================================================

-- ── Extensions ───────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ── Enumerations ─────────────────────────────────────────────
create type user_role as enum ('collector', 'manager', 'admin');

create type custody_event_type as enum (
  'collected',
  'field_jacketed',
  'transferred_to_lab',
  'in_preparation',
  'preparation_complete',
  'cataloged',
  'in_storage',
  'on_loan',
  'returned',
  'on_exhibit',
  'condition_note',
  'other'
);

-- ════════════════════════════════════════════════════════════
-- PROFILES  (administrative, not a DwC class)
-- ════════════════════════════════════════════════════════════
create table profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  full_name   text,
  role        user_role not null default 'collector',
  created_at  timestamptz not null default now()
);

-- Auto-create profile on signup
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name');
  return new;
end;
$$;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- ════════════════════════════════════════════════════════════
-- LOCATIONS  (DwC Location class)
-- Maps to: what field teams call a "site" or "dig"
-- ════════════════════════════════════════════════════════════
create table locations (
  id                   uuid primary key default uuid_generate_v4(),

  -- [WDC] Site codes and reference markers
  site_code            text not null,      -- short all-caps code, e.g. "DDD"
  site_name            text,               -- full descriptive name

  -- [DwC] Location
  verbatim_locality    text,               -- verbatimLocality: human-readable location
  decimal_latitude     numeric(10,7),      -- decimalLatitude
  decimal_longitude    numeric(10,7),      -- decimalLongitude
  geodetic_datum       text default 'WGS84', -- geodeticDatum

  -- [WDC] Field reference markers for radial measurements
  marker_1_label       text,              -- e.g. "N", "NE1"
  marker_2_label       text,              -- e.g. "2W", "SW2"

  -- [DwC] associated taxa observed at this location
  associated_taxa      text[] default '{}',  -- associatedTaxa: auto-updated when specimens are saved

  -- [WDC] Site-level geologic context (prefills new specimens at this site)
  formation            text,              -- primary formation at this site
  epoch                text,              -- primary epoch at this site

  -- [DwC]
  location_remarks     text,              -- locationRemarks

  -- Metadata
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  created_by           uuid references profiles(id)
);

-- ════════════════════════════════════════════════════════════
-- OCCURRENCES  (DwC Occurrence class + PaleoContext extension)
-- Maps to: what field teams call a "specimen" or "entity"
-- ════════════════════════════════════════════════════════════
create table occurrences (
  id                      uuid primary key default uuid_generate_v4(),

  -- ── DwC Record-level ──────────────────────────────────────
  -- [DwC]
  institution_code        text not null default 'WDC',  -- institutionCode
  collection_code         text default 'FIELD',         -- collectionCode
  catalog_number          text not null,                -- catalogNumber e.g. "DDD-2026-002"
  basis_of_record         text not null default 'FossilSpecimen', -- basisOfRecord

  -- ── DwC Occurrence ────────────────────────────────────────
  -- [DwC]
  occurrence_id           text,                         -- occurrenceID (external ref if needed)
  recorded_by             text,                         -- recordedBy: collector name(s)
  occurrence_status       text default 'present',       -- occurrenceStatus
  occurrence_remarks      text,                         -- occurrenceRemarks
  associated_occurrences  text,                         -- associatedOccurrences: nearby specimens
  associated_media        text,                         -- associatedMedia: photo references
  preparations            text[] default '{}',          -- preparations: jacketing/packaging (plaster, foam, etc.)
  chemicals_applied       text[] default '{}',          -- [WDC] field consolidants applied (cyano, paraloid, etc.)

  -- ── DwC Event ─────────────────────────────────────────────
  -- [DwC]
  event_date              date,                         -- eventDate: date discovered
  event_remarks           text,                         -- eventRemarks

  -- ── DwC Location ─────────────────────────────────────────
  -- [DwC]
  location_id             uuid references locations(id), -- FK to locations table
  decimal_latitude        numeric(10,7),                -- decimalLatitude: specimen-level GPS
  decimal_longitude       numeric(10,7),                -- decimalLongitude
  verbatim_locality       text,                         -- verbatimLocality
  verbatim_coordinates    text,                         -- verbatimCoordinates: raw GPS string

  -- ── DwC Geological Context (PaleoContext extension) ───────
  -- [PaleoCtx]
  earliest_period_or_lowest_system   text,             -- e.g. "Jurassic"
  latest_period_or_highest_system    text,
  earliest_epoch_or_lowest_series    text,             -- e.g. "Late Jurassic"
  latest_epoch_or_highest_series     text,
  formation                          text,             -- lithostratigraphic formation
  member                             text,             -- lithostratigraphic member
  bed                                text,             -- lithostratigraphic bed
  lowest_biostratigraphic_zone       text,
  lithologic_description             text,             -- verbatim geologic notes

  -- ── DwC Taxon ─────────────────────────────────────────────
  -- [DwC] (field-level; formalized by registrar in catalog app)
  scientific_name         text,                         -- scientificName
  kingdom                 text default 'Animalia',      -- kingdom
  phylum                  text,                         -- phylum
  "class"                 text,                         -- class
  "order"                 text,                         -- order
  family                  text,                         -- family
  genus                   text,                         -- genus
  specific_epithet        text,                         -- specificEpithet
  taxon_remarks           text,                         -- taxonRemarks
  identification_remarks  text,                         -- identificationRemarks
  type_status             text,                         -- typeStatus: holotype, paratype, etc.
  identified_by           text,                         -- identifiedBy

  -- ── WDC Field Collection ──────────────────────────────────
  -- Custom fields with no DwC equivalent

  -- [WDC] Skeletal element
  verbatim_element        text,                         -- e.g. "femur", "rib"
  element_side            text,                         -- "L", "R", "L/R"
  element_remarks         text,

  -- [WDC] Condition at discovery
  in_situ                 text,                         -- Yes / No / Unknown
  approx_position_known   text,
  bone_missing_pct        text,
  pre_depositional_pct    text,
  pre_depositional_condition  text[] default '{}',
  current_condition           text[] default '{}',

  -- [WDC] Field measurements
  orientation_degrees     numeric,                      -- azimuth, true north
  plunge_degrees          numeric,                      -- signed: + = top higher
  max_length_cm           numeric,
  mid_width_cm            numeric,

  -- [WDC] Radial map points (JSONB: A/B/C/D each with m1, m2 distances in cm)
  radial_measurements     jsonb default '{"A":{"m1":"","m2":""},"B":{"m1":"","m2":""},"C":{"m1":"","m2":""},"D":{"m1":"","m2":""}}',
  radial_point_count      integer default 1,

  -- [WDC] Mapping
  date_mapped             date,
  mapped_by               text,
  physical_map_date       date,
  placed_on_map_by        text,
  ready_for_removal       text,

  -- [WDC] Removal and collection workflow
  date_collected          date,
  collected_by            text,
  intern_staff            text,
  partially_removed       boolean default false,
  removal_method          text,
  temp_storage_location   text,
  collection_date         date,
  staff_signature         text,

  -- Metadata
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  created_by              uuid references profiles(id),
  sync_status             text default 'synced'
);

-- ════════════════════════════════════════════════════════════
-- CUSTODY_EVENTS  (WDC: chain of custody — immutable log)
-- Rows are never updated or deleted
-- ════════════════════════════════════════════════════════════
create table custody_events (
  id              uuid primary key default uuid_generate_v4(),
  occurrence_id   uuid not null references occurrences(id) on delete cascade,
  event_type      custody_event_type not null,
  handler         text,          -- person or institution taking custody
  location        text,          -- where the specimen went
  condition       text,          -- condition at time of event
  notes           text,
  created_at      timestamptz not null default now(),
  created_by      uuid references profiles(id)
);

-- ════════════════════════════════════════════════════════════
-- MEDIA  (DwC: associatedMedia — photos and files)
-- ════════════════════════════════════════════════════════════
create table media (
  id               uuid primary key default uuid_generate_v4(),
  occurrence_id    uuid not null references occurrences(id) on delete cascade,
  storage_path     text not null,    -- path in Supabase Storage bucket
  filename         text not null,    -- e.g. "DDD-2026-002_photo-001.jpg"
  sequence_number  integer not null default 1,
  media_type       text default 'StillImage',  -- DwC type: StillImage, MovingImage, etc.
  created_at       timestamptz not null default now(),
  created_by       uuid references profiles(id)
);

-- ── Updated-at triggers ───────────────────────────────────────
create or replace function set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
create trigger locations_updated_at   before update on locations    for each row execute procedure set_updated_at();
create trigger occurrences_updated_at before update on occurrences  for each row execute procedure set_updated_at();

-- ════════════════════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ════════════════════════════════════════════════════════════
alter table profiles       enable row level security;
alter table locations      enable row level security;
alter table occurrences    enable row level security;
alter table custody_events enable row level security;
alter table media          enable row level security;

-- Helper: current user's role
create or replace function my_role()
returns user_role language sql security definer stable as $$
  select role from profiles where id = auth.uid();
$$;

-- Profiles
create policy "Read all profiles"
  on profiles for select to authenticated using (true);
create policy "Update own profile"
  on profiles for update to authenticated using (id = auth.uid());

-- Locations
create policy "Read locations"
  on locations for select to authenticated using (true);
create policy "Create locations"
  on locations for insert to authenticated with check (auth.uid() is not null);
create policy "Managers update locations"
  on locations for update to authenticated using (my_role() in ('manager','admin'));
create policy "Admins delete locations"
  on locations for delete to authenticated using (my_role() = 'admin');

-- Occurrences
create policy "Read occurrences"
  on occurrences for select to authenticated using (true);
create policy "Create occurrences"
  on occurrences for insert to authenticated with check (auth.uid() is not null);
create policy "Collectors edit own; managers edit any"
  on occurrences for update to authenticated
  using (created_by = auth.uid() or my_role() in ('manager','admin'));
create policy "Admins delete occurrences"
  on occurrences for delete to authenticated using (my_role() = 'admin');

-- Custody events (append-only)
create policy "Read custody events"
  on custody_events for select to authenticated using (true);
create policy "Create custody events"
  on custody_events for insert to authenticated with check (auth.uid() is not null);

-- Media
create policy "Read media"
  on media for select to authenticated using (true);
create policy "Upload media"
  on media for insert to authenticated with check (auth.uid() is not null);
create policy "Managers delete media"
  on media for delete to authenticated using (my_role() in ('manager','admin'));

-- ── Storage bucket ────────────────────────────────────────────
insert into storage.buckets (id, name, public)
values ('media', 'media', false)
on conflict do nothing;

create policy "Upload to media bucket"
  on storage.objects for insert to authenticated
  with check (bucket_id = 'media');
create policy "Read from media bucket"
  on storage.objects for select to authenticated
  using (bucket_id = 'media');
create policy "Managers delete from media bucket"
  on storage.objects for delete to authenticated
  using (bucket_id = 'media' and my_role() in ('manager','admin'));

-- ════════════════════════════════════════════════════════════
-- NEXT STEPS (run these after the schema is created)
-- ════════════════════════════════════════════════════════════
-- 1. Go to Authentication → Users → Invite user (your email)
-- 2. Make yourself admin (replace with your email):
--
--    update profiles set role = 'admin'
--    where email = 'your@email.com';
