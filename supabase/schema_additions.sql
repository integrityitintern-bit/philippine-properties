-- =============================================================
--  Philippine Properties — Schema Additions (Lamudi-complete)
--  Run AFTER schema.sql
--  Adds: developers, projects, units, floor plans, price history,
--        saved searches, recently viewed, listing reports,
--        listing packages, agent subscriptions + missing columns
-- =============================================================

-- =============================================================
-- ENUMS — additions
-- =============================================================

alter type user_role_enum add value if not exists 'developer';

create type project_status_enum as enum (
  'Pre-selling',
  'Under Construction',
  'Ready for Occupancy',
  'Sold Out',
  'Coming Soon'
);

create type unit_status_enum as enum (
  'Available',
  'Reserved',
  'Sold'
);

create type report_reason_enum as enum (
  'spam',
  'incorrect_info',
  'already_sold',
  'duplicate',
  'offensive_content',
  'wrong_price',
  'other'
);

create type report_status_enum as enum (
  'pending',
  'reviewed',
  'resolved',
  'dismissed'
);

create type package_tier_enum as enum (
  'Free',
  'Basic',
  'Premium',
  'Featured'
);

-- =============================================================
-- DEVELOPERS  (property development companies — Ayala, SMDC, etc.)
-- =============================================================

create table developers (
  id              uuid primary key references profiles (id) on delete cascade,
  company_name    text not null,
  slug            text not null unique,
  logo_url        text,
  cover_url       text,
  description     text,
  address         text,
  city            text,
  phone           text,
  email           text,
  website         text,
  facebook_url    text,
  instagram_url   text,
  youtube_url     text,
  is_verified     boolean not null default false,
  is_active       boolean not null default true,
  total_projects  int not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- =============================================================
-- PROJECTS  (pre-selling or RFO developments with multiple units)
-- =============================================================

create table projects (
  id               uuid primary key default uuid_generate_v4(),
  slug             text not null unique,
  name             text not null,
  developer_id     uuid references developers (id) on delete set null,
  agent_id         uuid references agents (id) on delete set null,
  property_type    property_type_enum not null,
  description      text,
  status           project_status_enum not null default 'Pre-selling',

  -- Pricing range
  min_price        numeric(15,2),
  max_price        numeric(15,2),
  min_floor_area   numeric(10,2),
  max_floor_area   numeric(10,2),

  -- Units
  total_units      int,
  available_units  int,

  -- Dates
  turnover_date    date,
  completion_pct   int,                     -- 0–100%

  -- Location
  full_address     text,
  barangay         text,
  city             text,
  province         text,
  latitude         numeric(10,7),
  longitude        numeric(10,7),

  -- Media
  cover_url        text,
  virtual_tour_url text,
  video_url        text,                    -- YouTube embed

  -- Financing
  accepts_pag_ibig  boolean not null default false,
  accepts_bank_loan boolean not null default false,
  accepts_in_house  boolean not null default false,

  -- Flags
  is_featured       boolean not null default false,
  is_verified       boolean not null default false,

  -- Stats
  view_count        int not null default 0,
  inquiry_count     int not null default 0,

  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create index idx_projects_status       on projects (status);
create index idx_projects_city         on projects (city);
create index idx_projects_developer_id on projects (developer_id);
create index idx_projects_is_featured  on projects (is_featured) where is_featured = true;

-- =============================================================
-- PROJECT IMAGES
-- =============================================================

create table project_images (
  id           uuid primary key default uuid_generate_v4(),
  project_id   uuid not null references projects (id) on delete cascade,
  storage_path text not null,
  url          text not null,
  alt_text     text,
  is_primary   boolean not null default false,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);

create unique index idx_project_images_primary
  on project_images (project_id)
  where is_primary = true;

-- =============================================================
-- PROJECT UNITS  (individual unit types within a project)
-- =============================================================

create table project_units (
  id           uuid primary key default uuid_generate_v4(),
  project_id   uuid not null references projects (id) on delete cascade,
  property_id  uuid references properties (id) on delete set null,  -- links to full listing if available
  unit_type    text not null,                -- 'Studio', '1BR', '2BR', '3BR', 'Penthouse'
  floor_area   numeric(10,2),
  price        numeric(15,2),
  bedrooms     int,
  bathrooms    int,
  floor_level  int,
  status       unit_status_enum not null default 'Available',
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);

create index idx_project_units_project_id on project_units (project_id);
create index idx_project_units_status     on project_units (status);

-- =============================================================
-- FLOOR PLANS  (for both individual properties and projects)
-- =============================================================

create table floor_plans (
  id           uuid primary key default uuid_generate_v4(),
  property_id  uuid references properties (id) on delete cascade,
  project_id   uuid references projects (id) on delete cascade,
  unit_type    text,                         -- '1BR', '2BR', etc.
  label        text,                         -- 'Ground Floor', 'Tower A'
  storage_path text not null,
  url          text not null,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now(),
  check (property_id is not null or project_id is not null)
);

-- =============================================================
-- PRICE HISTORY  (track every price change on a property)
-- =============================================================

create table price_history (
  id           uuid primary key default uuid_generate_v4(),
  property_id  uuid not null references properties (id) on delete cascade,
  old_price    numeric(15,2),
  new_price    numeric(15,2) not null,
  changed_by   uuid references profiles (id) on delete set null,
  note         text,
  recorded_at  timestamptz not null default now()
);

create index idx_price_history_property on price_history (property_id, recorded_at desc);

-- Auto-log price changes
create or replace function log_price_change()
returns trigger language plpgsql as $$
begin
  if old.price is distinct from new.price then
    insert into price_history (property_id, old_price, new_price)
    values (new.id, old.price, new.price);
  end if;
  return new;
end;
$$;

create trigger trg_price_history
  after update of price on properties
  for each row execute procedure log_price_change();

-- =============================================================
-- SAVED SEARCHES  (persistent search filter subscriptions)
-- =============================================================

create table saved_searches (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references profiles (id) on delete cascade,
  name          text,                        -- user label e.g. "Makati Condos Under 5M"
  filters       jsonb not null default '{}', -- all search params as JSON
  alert_enabled boolean not null default false,
  last_alerted  timestamptz,
  result_count  int,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index idx_saved_searches_user on saved_searches (user_id);

-- =============================================================
-- RECENTLY VIEWED  (server-side, one row per user+property pair)
-- =============================================================

create table recently_viewed (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references profiles (id) on delete cascade,
  property_id  uuid not null references properties (id) on delete cascade,
  viewed_at    timestamptz not null default now(),
  unique (user_id, property_id)
);

-- On re-visit, update the timestamp instead of inserting a new row
create or replace function upsert_recently_viewed(p_user uuid, p_property uuid)
returns void language plpgsql security definer as $$
begin
  insert into recently_viewed (user_id, property_id, viewed_at)
  values (p_user, p_property, now())
  on conflict (user_id, property_id)
  do update set viewed_at = now();
end;
$$;

create index idx_recently_viewed_user on recently_viewed (user_id, viewed_at desc);

-- =============================================================
-- LISTING REPORTS  (report spam / incorrect / already sold)
-- =============================================================

create table listing_reports (
  id            uuid primary key default uuid_generate_v4(),
  property_id   uuid not null references properties (id) on delete cascade,
  reporter_id   uuid references profiles (id) on delete set null,
  reporter_email text,
  reason        report_reason_enum not null,
  description   text,
  status        report_status_enum not null default 'pending',
  reviewed_by   uuid references profiles (id) on delete set null,
  reviewed_at   timestamptz,
  created_at    timestamptz not null default now()
);

create index idx_reports_property on listing_reports (property_id);
create index idx_reports_status   on listing_reports (status);

-- =============================================================
-- LISTING PACKAGES  (Free / Basic / Premium / Featured tiers)
-- =============================================================

create table listing_packages (
  id              uuid primary key default uuid_generate_v4(),
  tier            package_tier_enum not null unique,
  price_php       numeric(10,2) not null default 0,
  duration_days   int not null default 30,
  max_listings    int,                       -- null = unlimited
  max_photos      int not null default 5,
  has_featured    boolean not null default false,
  has_analytics   boolean not null default false,
  has_priority    boolean not null default false,  -- appears first in search
  has_verified_badge boolean not null default false,
  description     text,
  is_active       boolean not null default true,
  created_at      timestamptz not null default now()
);

-- Seed default packages
insert into listing_packages (tier, price_php, duration_days, max_listings, max_photos, has_featured, has_analytics, has_priority, has_verified_badge, description) values
  ('Free',     0,       30,  3,    5,  false, false, false, false, 'Basic free listing — 3 active listings, 5 photos'),
  ('Basic',    999,     30,  10,   15, false, false, false, false, 'For active sellers — 10 listings, 15 photos per listing'),
  ('Premium',  2999,    30,  null, 30, false, true,  false, true,  'For agents — unlimited listings, analytics, verified badge'),
  ('Featured', 1499,    30,  null, 30, true,  true,  true,  true,  'Top placement in search results + featured homepage slot');

-- =============================================================
-- AGENT SUBSCRIPTIONS  (which package an agent is on)
-- =============================================================

create table agent_subscriptions (
  id           uuid primary key default uuid_generate_v4(),
  agent_id     uuid not null references agents (id) on delete cascade,
  package_id   uuid not null references listing_packages (id),
  starts_at    timestamptz not null default now(),
  expires_at   timestamptz not null,
  is_active    boolean not null default true,
  payment_ref  text,
  created_at   timestamptz not null default now()
);

create index idx_subscriptions_agent   on agent_subscriptions (agent_id);
create index idx_subscriptions_active  on agent_subscriptions (is_active, expires_at);

-- =============================================================
-- ADD MISSING COLUMNS TO PROPERTIES
-- =============================================================

alter table properties
  add column if not exists virtual_tour_url  text,
  add column if not exists video_url         text,      -- YouTube embed URL
  add column if not exists developer_id      uuid references developers (id) on delete set null,
  add column if not exists project_id        uuid references projects (id) on delete set null;

create index if not exists idx_properties_developer_id on properties (developer_id);
create index if not exists idx_properties_project_id   on properties (project_id);

-- =============================================================
-- RLS — new tables
-- =============================================================

alter table developers          enable row level security;
alter table projects            enable row level security;
alter table project_images      enable row level security;
alter table project_units       enable row level security;
alter table floor_plans         enable row level security;
alter table price_history       enable row level security;
alter table saved_searches      enable row level security;
alter table recently_viewed     enable row level security;
alter table listing_reports     enable row level security;
alter table listing_packages    enable row level security;
alter table agent_subscriptions enable row level security;

-- DEVELOPERS
create policy "developers_public_read"  on developers for select using (is_active = true);
create policy "developers_update_own"   on developers for update using (auth.uid() = id);
create policy "developers_admin_all"    on developers for all
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- PROJECTS
create policy "projects_public_read"    on projects for select using (true);
create policy "projects_developer_write" on projects for all
  using (auth.uid() = developer_id);
create policy "projects_agent_write"    on projects for all
  using (auth.uid() = agent_id);
create policy "projects_admin_all"      on projects for all
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- PROJECT IMAGES + UNITS
create policy "project_images_public_read" on project_images for select using (true);
create policy "project_units_public_read"  on project_units for select using (true);
create policy "floor_plans_public_read"    on floor_plans for select using (true);

-- PRICE HISTORY
create policy "price_history_public_read" on price_history for select using (true);

-- SAVED SEARCHES
create policy "saved_searches_user_crud" on saved_searches for all using (auth.uid() = user_id);

-- RECENTLY VIEWED
create policy "recently_viewed_user_crud" on recently_viewed for all using (auth.uid() = user_id);

-- LISTING REPORTS
create policy "reports_anon_insert"  on listing_reports for insert with check (true);
create policy "reports_admin_all"    on listing_reports for all
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- LISTING PACKAGES
create policy "packages_public_read" on listing_packages for select using (is_active = true);
create policy "packages_admin_all"   on listing_packages for all
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- AGENT SUBSCRIPTIONS
create policy "subscriptions_agent_read"  on agent_subscriptions for select using (auth.uid() = agent_id);
create policy "subscriptions_admin_all"   on agent_subscriptions for all
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- =============================================================
-- UPDATE STORAGE BUCKETS
-- =============================================================

-- Additional buckets needed:
--   supabase.storage.createBucket('project-images', { public: true, fileSizeLimit: 10485760 });
--   supabase.storage.createBucket('floor-plans',    { public: true, fileSizeLimit: 10485760 });
--   supabase.storage.createBucket('developer-assets', { public: true, fileSizeLimit: 10485760 });

-- =============================================================
-- DONE — Full Lamudi-structure schema complete
-- =============================================================
-- Tables added in this file:
--   developers, projects, project_images, project_units,
--   floor_plans, price_history, saved_searches, recently_viewed,
--   listing_reports, listing_packages, agent_subscriptions
--
-- Columns added to properties:
--   virtual_tour_url, video_url, developer_id, project_id
--
-- New enums: project_status, unit_status, report_reason,
--            report_status, package_tier
--            + developer added to user_role_enum
