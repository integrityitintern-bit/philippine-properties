-- =============================================================
--  Philippine Properties — Supabase Schema
--  Lamudi-inspired real estate listing platform
--  Run this in: Supabase Dashboard → SQL Editor → New query
-- =============================================================

-- Enable required extensions
create extension if not exists "uuid-ossp";
create extension if not exists "pg_trgm";       -- for full-text search
create extension if not exists "unaccent";       -- for accent-insensitive search

-- =============================================================
-- ENUMS
-- =============================================================

create type listing_type_enum as enum (
  'For Sale',
  'For Rent',
  'Pre-selling',
  'Lease to Own'
);

create type property_type_enum as enum (
  'House & Lot',
  'Condo',
  'Townhouse',
  'Apartment',
  'Land & Lot',
  'Commercial',
  'Warehouse',
  'Office Space'
);

create type property_status_enum as enum (
  'active',
  'sold',
  'rented',
  'pending',
  'draft',
  'archived'
);

create type furnished_enum as enum (
  'Unfurnished',
  'Semi-furnished',
  'Fully Furnished'
);

create type user_role_enum as enum (
  'buyer',
  'seller',
  'agent',
  'admin'
);

create type inquiry_status_enum as enum (
  'new',
  'read',
  'replied',
  'closed'
);

create type viewing_status_enum as enum (
  'pending',
  'confirmed',
  'cancelled',
  'completed'
);

create type amenity_category_enum as enum (
  'building',
  'unit',
  'outdoor',
  'nearby'
);

-- =============================================================
-- PROFILES  (extends auth.users — one row per auth user)
-- =============================================================

create table profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  full_name     text,
  phone         text,
  avatar_url    text,
  role          user_role_enum not null default 'buyer',
  is_verified   boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

-- Auto-create profile row when a new user signs up
create or replace function handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into profiles (id, full_name, avatar_url)
  values (
    new.id,
    new.raw_user_meta_data->>'full_name',
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure handle_new_user();

-- =============================================================
-- AGENCIES
-- =============================================================

create table agencies (
  id           uuid primary key default uuid_generate_v4(),
  name         text not null,
  slug         text not null unique,
  logo_url     text,
  cover_url    text,
  description  text,
  address      text,
  city         text,
  phone        text,
  email        text,
  website      text,
  facebook_url text,
  is_verified  boolean not null default false,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- =============================================================
-- AGENTS  (profile + agency membership)
-- =============================================================

create table agents (
  id              uuid primary key references profiles (id) on delete cascade,
  agency_id       uuid references agencies (id) on delete set null,
  license_number  text,
  bio             text,
  specializations text[],               -- ['Condo', 'House & Lot']
  service_areas   text[],               -- ['Makati', 'BGC', 'Quezon City']
  facebook_url    text,
  instagram_url   text,
  viber_number    text,
  whatsapp_number text,
  years_experience int,
  total_listings  int not null default 0,
  total_sold      int not null default 0,
  rating_avg      numeric(3,2),
  rating_count    int not null default 0,
  is_featured     boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- =============================================================
-- AMENITIES  (lookup / master list)
-- =============================================================

create table amenities (
  id       uuid primary key default uuid_generate_v4(),
  name     text not null unique,
  icon     text,                        -- emoji or icon class
  category amenity_category_enum not null default 'building'
);

insert into amenities (name, icon, category) values
  -- Building
  ('Swimming Pool',     '🏊', 'building'),
  ('Gym / Fitness Center', '🏋️', 'building'),
  ('24/7 Security',     '🔒', 'building'),
  ('CCTV',              '📷', 'building'),
  ('Elevator',          '🛗', 'building'),
  ('Lobby',             '🏛️', 'building'),
  ('Function Hall',     '🎪', 'building'),
  ('Rooftop Deck',      '🏙️', 'building'),
  ('Business Center',   '💼', 'building'),
  ('Concierge',         '🛎️', 'building'),
  ('Laundry Area',      '👕', 'building'),
  ('Generator / Back-up Power', '⚡', 'building'),
  -- Unit
  ('Air Conditioning',  '❄️', 'unit'),
  ('Balcony',           '🌿', 'unit'),
  ('Built-in Closet',   '🚪', 'unit'),
  ('Bathtub',           '🛁', 'unit'),
  ('Kitchen Appliances','🍳', 'unit'),
  -- Outdoor
  ('Parking Slot',      '🅿️', 'outdoor'),
  ('Garden',            '🌱', 'outdoor'),
  ('Basketball Court',  '🏀', 'outdoor'),
  ('Jogging Path',      '🏃', 'outdoor'),
  ('Playground',        '🛝', 'outdoor'),
  -- Nearby
  ('Near School',       '🏫', 'nearby'),
  ('Near Hospital',     '🏥', 'nearby'),
  ('Near Mall',         '🛍️', 'nearby'),
  ('Near MRT/LRT',      '🚇', 'nearby'),
  ('Near Church',       '⛪', 'nearby');

-- =============================================================
-- PROPERTIES  (core listing table)
-- =============================================================

create table properties (
  id                 uuid primary key default uuid_generate_v4(),
  slug               text not null unique,

  -- Content
  title              text not null,
  description        text,
  property_type      property_type_enum not null,
  listing_type       listing_type_enum not null,
  status             property_status_enum not null default 'active',

  -- Pricing
  price              numeric(15,2),
  price_per_sqm      numeric(12,2),           -- computed on insert/update
  price_is_negotiable boolean not null default false,

  -- Specs
  bedrooms           int,
  bathrooms          int,
  floor_area         numeric(10,2),           -- sqm
  lot_area           numeric(10,2),           -- sqm
  total_floors       int,
  floor_level        int,                     -- for condos
  year_built         int,
  parking_spaces     int not null default 0,
  furnished          furnished_enum,

  -- Ownership / listing
  agent_id           uuid references agents (id) on delete set null,
  agency_id          uuid references agencies (id) on delete set null,
  owner_id           uuid references profiles (id) on delete set null,  -- if direct listing

  -- Flags
  is_featured        boolean not null default false,
  is_verified        boolean not null default false,
  is_pre_selling     boolean not null default false,
  accepts_pag_ibig   boolean not null default false,
  accepts_bank_loan  boolean not null default false,
  accepts_in_house   boolean not null default false,

  -- Stats
  view_count         int not null default 0,
  inquiry_count      int not null default 0,
  save_count         int not null default 0,

  -- SEO / meta
  meta_title         text,
  meta_description   text,

  -- Timestamps
  published_at       timestamptz,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),

  -- WordPress migration reference (remove after full migration)
  wp_post_id         int unique
);

-- Auto-compute price_per_sqm
create or replace function compute_price_per_sqm()
returns trigger language plpgsql as $$
begin
  if new.price is not null and new.floor_area is not null and new.floor_area > 0 then
    new.price_per_sqm := round(new.price / new.floor_area, 2);
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger trg_properties_price_per_sqm
  before insert or update on properties
  for each row execute procedure compute_price_per_sqm();

-- =============================================================
-- PROPERTY LOCATIONS  (1-to-1 with properties)
-- =============================================================

create table property_locations (
  id             uuid primary key default uuid_generate_v4(),
  property_id    uuid not null unique references properties (id) on delete cascade,
  full_address   text,
  barangay       text,
  city           text,
  province       text,
  region         text,
  zip_code       text,
  latitude       numeric(10,7),
  longitude      numeric(10,7),
  map_embed_url  text                        -- cached Google Maps embed URL
);

-- =============================================================
-- PROPERTY IMAGES
-- =============================================================

create table property_images (
  id           uuid primary key default uuid_generate_v4(),
  property_id  uuid not null references properties (id) on delete cascade,
  storage_path text not null,               -- Supabase Storage: property-images/{property_id}/{filename}
  url          text not null,               -- public URL
  alt_text     text,
  is_primary   boolean not null default false,
  sort_order   int not null default 0,
  created_at   timestamptz not null default now()
);

-- Only one primary image per property
create unique index idx_property_images_primary
  on property_images (property_id)
  where is_primary = true;

-- =============================================================
-- PROPERTY ↔ AMENITIES  (many-to-many)
-- =============================================================

create table property_amenities (
  property_id  uuid not null references properties (id) on delete cascade,
  amenity_id   uuid not null references amenities (id) on delete cascade,
  primary key (property_id, amenity_id)
);

-- =============================================================
-- SAVED / FAVOURITES
-- =============================================================

create table saved_properties (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references profiles (id) on delete cascade,
  property_id  uuid not null references properties (id) on delete cascade,
  created_at   timestamptz not null default now(),
  unique (user_id, property_id)
);

-- Keep save_count on properties in sync
create or replace function sync_save_count()
returns trigger language plpgsql as $$
begin
  if TG_OP = 'INSERT' then
    update properties set save_count = save_count + 1 where id = new.property_id;
  elsif TG_OP = 'DELETE' then
    update properties set save_count = save_count - 1 where id = old.property_id;
  end if;
  return null;
end;
$$;

create trigger trg_save_count
  after insert or delete on saved_properties
  for each row execute procedure sync_save_count();

-- =============================================================
-- INQUIRIES  (contact agent / general inquiries)
-- =============================================================

create table inquiries (
  id            uuid primary key default uuid_generate_v4(),
  property_id   uuid references properties (id) on delete set null,
  agent_id      uuid references agents (id) on delete set null,
  sender_id     uuid references profiles (id) on delete set null,   -- null if guest
  sender_name   text not null,
  sender_email  text not null,
  sender_phone  text,
  message       text not null,
  status        inquiry_status_enum not null default 'new',
  replied_at    timestamptz,
  created_at    timestamptz not null default now()
);

-- Keep inquiry_count on properties in sync
create or replace function sync_inquiry_count()
returns trigger language plpgsql as $$
begin
  if TG_OP = 'INSERT' and new.property_id is not null then
    update properties set inquiry_count = inquiry_count + 1 where id = new.property_id;
  end if;
  return null;
end;
$$;

create trigger trg_inquiry_count
  after insert on inquiries
  for each row execute procedure sync_inquiry_count();

-- =============================================================
-- VIEWINGS  (schedule a property viewing)
-- =============================================================

create table viewings (
  id               uuid primary key default uuid_generate_v4(),
  property_id      uuid not null references properties (id) on delete cascade,
  agent_id         uuid references agents (id) on delete set null,
  user_id          uuid references profiles (id) on delete set null,   -- null if guest
  guest_name       text,
  guest_email      text,
  guest_phone      text,
  preferred_date   date not null,
  preferred_time   time,
  status           viewing_status_enum not null default 'pending',
  notes            text,
  confirmed_at     timestamptz,
  created_at       timestamptz not null default now()
);

-- =============================================================
-- OPEN HOUSES
-- =============================================================

create table open_houses (
  id             uuid primary key default uuid_generate_v4(),
  property_id    uuid not null references properties (id) on delete cascade,
  agent_id       uuid references agents (id) on delete set null,
  event_date     date not null,
  start_time     time not null,
  end_time       time not null,
  max_attendees  int,
  notes          text,
  is_cancelled   boolean not null default false,
  created_at     timestamptz not null default now()
);

create table open_house_rsvps (
  id             uuid primary key default uuid_generate_v4(),
  open_house_id  uuid not null references open_houses (id) on delete cascade,
  user_id        uuid references profiles (id) on delete set null,
  name           text not null,
  email          text not null,
  phone          text,
  created_at     timestamptz not null default now(),
  unique (open_house_id, email)
);

-- =============================================================
-- PROPERTY ALERTS  (email-notify on new matching listings)
-- =============================================================

create table property_alerts (
  id             uuid primary key default uuid_generate_v4(),
  email          text not null,
  user_id        uuid references profiles (id) on delete cascade,
  listing_type   listing_type_enum,
  property_type  property_type_enum,
  city           text,
  province       text,
  min_price      numeric(15,2),
  max_price      numeric(15,2),
  min_bedrooms   int,
  min_bathrooms  int,
  max_floor_area numeric(10,2),
  is_active      boolean not null default true,
  last_notified  timestamptz,
  created_at     timestamptz not null default now()
);

-- =============================================================
-- NEWSLETTER SUBSCRIBERS
-- =============================================================

create table newsletter_subscribers (
  id         uuid primary key default uuid_generate_v4(),
  email      text not null unique,
  user_id    uuid references profiles (id) on delete set null,
  is_active  boolean not null default true,
  created_at timestamptz not null default now()
);

-- =============================================================
-- AGENT REVIEWS
-- =============================================================

create table agent_reviews (
  id           uuid primary key default uuid_generate_v4(),
  agent_id     uuid not null references agents (id) on delete cascade,
  reviewer_id  uuid not null references profiles (id) on delete cascade,
  property_id  uuid references properties (id) on delete set null,
  rating       int not null check (rating between 1 and 5),
  comment      text,
  created_at   timestamptz not null default now(),
  unique (agent_id, reviewer_id)              -- one review per agent per user
);

-- Sync rating_avg and rating_count on agents
create or replace function sync_agent_rating()
returns trigger language plpgsql as $$
begin
  update agents
  set
    rating_avg   = (select round(avg(rating)::numeric, 2) from agent_reviews where agent_id = coalesce(new.agent_id, old.agent_id)),
    rating_count = (select count(*) from agent_reviews where agent_id = coalesce(new.agent_id, old.agent_id))
  where id = coalesce(new.agent_id, old.agent_id);
  return null;
end;
$$;

create trigger trg_agent_rating
  after insert or update or delete on agent_reviews
  for each row execute procedure sync_agent_rating();

-- =============================================================
-- PROPERTY VIEWS LOG  (analytics — one row per visit)
-- =============================================================

create table property_views (
  id           uuid primary key default uuid_generate_v4(),
  property_id  uuid not null references properties (id) on delete cascade,
  user_id      uuid references profiles (id) on delete set null,
  ip_hash      text,                          -- hashed for privacy
  user_agent   text,
  referrer     text,
  viewed_at    timestamptz not null default now()
);

-- Bump view_count on properties
create or replace function sync_view_count()
returns trigger language plpgsql as $$
begin
  update properties set view_count = view_count + 1 where id = new.property_id;
  return null;
end;
$$;

create trigger trg_view_count
  after insert on property_views
  for each row execute procedure sync_view_count();

-- =============================================================
-- COMPARE LIST  (session-level, optional persistence)
-- =============================================================

create table compare_lists (
  id           uuid primary key default uuid_generate_v4(),
  user_id      uuid not null references profiles (id) on delete cascade,
  property_ids uuid[] not null default '{}',
  updated_at   timestamptz not null default now(),
  unique (user_id)
);

-- =============================================================
-- INDEXES
-- =============================================================

-- Properties — search filters
create index idx_properties_status        on properties (status);
create index idx_properties_listing_type  on properties (listing_type);
create index idx_properties_property_type on properties (property_type);
create index idx_properties_price         on properties (price);
create index idx_properties_bedrooms      on properties (bedrooms);
create index idx_properties_agent_id      on properties (agent_id);
create index idx_properties_is_featured   on properties (is_featured) where is_featured = true;
create index idx_properties_published_at  on properties (published_at desc);
create index idx_properties_wp_post_id    on properties (wp_post_id);

-- Full-text search on title + description
create index idx_properties_fts
  on properties
  using gin (to_tsvector('english', coalesce(title,'') || ' ' || coalesce(description,'')));

-- Locations — city/province filtering
create index idx_locations_city      on property_locations (city);
create index idx_locations_province  on property_locations (province);
create index idx_locations_latlng    on property_locations (latitude, longitude);

-- Images
create index idx_images_property_id  on property_images (property_id, sort_order);

-- Inquiries
create index idx_inquiries_agent_id    on inquiries (agent_id);
create index idx_inquiries_property_id on inquiries (property_id);
create index idx_inquiries_status      on inquiries (status);

-- Views analytics
create index idx_views_property_id  on property_views (property_id);
create index idx_views_viewed_at    on property_views (viewed_at desc);

-- =============================================================
-- VIEWS  (handy query shortcuts)
-- =============================================================

-- Active listings with location + primary image + agent name
create or replace view active_listings as
select
  p.id,
  p.slug,
  p.title,
  p.listing_type,
  p.property_type,
  p.price,
  p.price_per_sqm,
  p.bedrooms,
  p.bathrooms,
  p.floor_area,
  p.lot_area,
  p.parking_spaces,
  p.furnished,
  p.is_featured,
  p.is_verified,
  p.view_count,
  p.published_at,
  -- Location
  loc.city,
  loc.province,
  loc.barangay,
  loc.full_address,
  loc.latitude,
  loc.longitude,
  -- Primary image
  img.url        as primary_image_url,
  -- Agent
  pro.full_name  as agent_name,
  pro.phone      as agent_phone,
  agt.whatsapp_number as agent_whatsapp
from properties p
left join property_locations loc on loc.property_id = p.id
left join property_images img    on img.property_id = p.id and img.is_primary = true
left join agents agt             on agt.id = p.agent_id
left join profiles pro           on pro.id = agt.id
where p.status = 'active';

-- =============================================================
-- HELPER FUNCTIONS
-- =============================================================

-- Slug generator (title → kebab-case)
create or replace function slugify(input text)
returns text language plpgsql immutable as $$
begin
  return lower(
    regexp_replace(
      regexp_replace(
        unaccent(input),
        '[^a-zA-Z0-9\s-]', '', 'g'
      ),
      '\s+', '-', 'g'
    )
  );
end;
$$;

-- Increment view count (called from Edge Function to avoid RLS issues)
create or replace function increment_view_count(p_id uuid)
returns void language plpgsql security definer as $$
begin
  update properties set view_count = view_count + 1 where id = p_id;
end;
$$;

-- Full property search with filters
create or replace function search_properties(
  p_listing_type   text     default null,
  p_property_type  text     default null,
  p_city           text     default null,
  p_province       text     default null,
  p_min_price      numeric  default null,
  p_max_price      numeric  default null,
  p_min_bedrooms   int      default null,
  p_min_bathrooms  int      default null,
  p_min_floor_area numeric  default null,
  p_max_floor_area numeric  default null,
  p_keyword        text     default null,
  p_limit          int      default 20,
  p_offset         int      default 0
)
returns table (
  id              uuid,
  slug            text,
  title           text,
  listing_type    listing_type_enum,
  property_type   property_type_enum,
  price           numeric,
  price_per_sqm   numeric,
  bedrooms        int,
  bathrooms       int,
  floor_area      numeric,
  city            text,
  province        text,
  primary_image   text,
  is_featured     boolean,
  view_count      int,
  published_at    timestamptz,
  total_count     bigint
)
language plpgsql as $$
begin
  return query
  with filtered as (
    select p.*, loc.city, loc.province, img.url as primary_image
    from properties p
    left join property_locations loc on loc.property_id = p.id
    left join property_images img    on img.property_id = p.id and img.is_primary = true
    where
      p.status = 'active'
      and (p_listing_type  is null or p.listing_type::text  = p_listing_type)
      and (p_property_type is null or p.property_type::text = p_property_type)
      and (p_city          is null or loc.city ilike '%' || p_city || '%')
      and (p_province      is null or loc.province ilike '%' || p_province || '%')
      and (p_min_price     is null or p.price >= p_min_price)
      and (p_max_price     is null or p.price <= p_max_price)
      and (p_min_bedrooms  is null or p.bedrooms >= p_min_bedrooms)
      and (p_min_bathrooms is null or p.bathrooms >= p_min_bathrooms)
      and (p_min_floor_area is null or p.floor_area >= p_min_floor_area)
      and (p_max_floor_area is null or p.floor_area <= p_max_floor_area)
      and (p_keyword       is null or
           to_tsvector('english', coalesce(p.title,'') || ' ' || coalesce(p.description,''))
           @@ plainto_tsquery('english', p_keyword))
  )
  select
    f.id, f.slug, f.title, f.listing_type, f.property_type,
    f.price, f.price_per_sqm, f.bedrooms, f.bathrooms, f.floor_area,
    f.city, f.province, f.primary_image, f.is_featured, f.view_count,
    f.published_at,
    count(*) over () as total_count
  from filtered f
  order by f.is_featured desc, f.published_at desc nulls last
  limit p_limit offset p_offset;
end;
$$;

-- =============================================================
-- ROW LEVEL SECURITY (RLS)
-- =============================================================

-- Enable RLS on every user-facing table
alter table profiles            enable row level security;
alter table agencies            enable row level security;
alter table agents              enable row level security;
alter table properties          enable row level security;
alter table property_locations  enable row level security;
alter table property_images     enable row level security;
alter table property_amenities  enable row level security;
alter table saved_properties    enable row level security;
alter table inquiries           enable row level security;
alter table viewings            enable row level security;
alter table open_houses         enable row level security;
alter table open_house_rsvps    enable row level security;
alter table property_alerts     enable row level security;
alter table newsletter_subscribers enable row level security;
alter table agent_reviews       enable row level security;
alter table property_views      enable row level security;
alter table compare_lists       enable row level security;

-- ---- PROFILES ----
create policy "profiles_select_own"  on profiles for select using (auth.uid() = id);
create policy "profiles_update_own"  on profiles for update using (auth.uid() = id);
-- Admins see all
create policy "profiles_select_admin" on profiles for select
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- ---- AGENCIES ----
create policy "agencies_public_read"  on agencies for select using (is_active = true);
create policy "agencies_admin_all"    on agencies for all
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- ---- AGENTS ----
create policy "agents_public_read"   on agents for select using (true);
create policy "agents_update_own"    on agents for update using (auth.uid() = id);
create policy "agents_admin_all"     on agents for all
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- ---- PROPERTIES ----
-- Anyone reads active listings
create policy "properties_public_read" on properties for select
  using (status = 'active');
-- Owner / agent sees their own (all statuses)
create policy "properties_owner_read" on properties for select
  using (auth.uid() = agent_id or auth.uid() = owner_id);
-- Agents can insert
create policy "properties_agent_insert" on properties for insert
  with check (exists (select 1 from profiles where id = auth.uid() and role in ('agent','admin')));
-- Agent updates their own
create policy "properties_owner_update" on properties for update
  using (auth.uid() = agent_id or auth.uid() = owner_id);
-- Admins can do anything
create policy "properties_admin_all" on properties for all
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- ---- PROPERTY LOCATIONS / IMAGES / AMENITIES — follow property ownership ----
create policy "locations_public_read" on property_locations for select using (true);
create policy "images_public_read"    on property_images    for select using (true);
create policy "amenities_public_read" on property_amenities for select using (true);

create policy "locations_owner_write" on property_locations for all
  using (exists (select 1 from properties where id = property_id
    and (agent_id = auth.uid() or owner_id = auth.uid())));
create policy "images_owner_write" on property_images for all
  using (exists (select 1 from properties where id = property_id
    and (agent_id = auth.uid() or owner_id = auth.uid())));
create policy "amenities_owner_write" on property_amenities for all
  using (exists (select 1 from properties where id = property_id
    and (agent_id = auth.uid() or owner_id = auth.uid())));

-- ---- SAVED PROPERTIES ----
create policy "saved_user_crud" on saved_properties for all using (auth.uid() = user_id);

-- ---- INQUIRIES ----
-- Anyone (incl. anon) can submit
create policy "inquiries_anon_insert" on inquiries for insert with check (true);
-- Agent reads inquiries addressed to them
create policy "inquiries_agent_read" on inquiries for select
  using (agent_id = auth.uid());
-- Sender reads their own (if logged in)
create policy "inquiries_sender_read" on inquiries for select
  using (sender_id = auth.uid());
-- Admins see all
create policy "inquiries_admin_all" on inquiries for all
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- ---- VIEWINGS ----
create policy "viewings_anon_insert"  on viewings for insert with check (true);
create policy "viewings_user_read"    on viewings for select using (auth.uid() = user_id);
create policy "viewings_agent_read"   on viewings for select using (auth.uid() = agent_id);
create policy "viewings_agent_update" on viewings for update using (auth.uid() = agent_id);
create policy "viewings_admin_all"    on viewings for all
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- ---- OPEN HOUSES ----
create policy "open_houses_public_read" on open_houses for select using (is_cancelled = false);
create policy "open_houses_agent_write" on open_houses for all
  using (auth.uid() = agent_id);
create policy "open_house_rsvps_anon_insert" on open_house_rsvps for insert with check (true);
create policy "open_house_rsvps_user_read"   on open_house_rsvps for select using (auth.uid() = user_id);

-- ---- PROPERTY ALERTS ----
create policy "alerts_anon_insert" on property_alerts for insert with check (true);
create policy "alerts_user_crud"   on property_alerts for all using (auth.uid() = user_id);

-- ---- NEWSLETTER ----
create policy "newsletter_anon_insert" on newsletter_subscribers for insert with check (true);
create policy "newsletter_user_crud"   on newsletter_subscribers for all
  using (auth.uid() = user_id);

-- ---- AGENT REVIEWS ----
create policy "reviews_public_read"    on agent_reviews for select using (true);
create policy "reviews_user_insert"    on agent_reviews for insert
  with check (auth.uid() = reviewer_id);
create policy "reviews_user_update"    on agent_reviews for update
  using (auth.uid() = reviewer_id);

-- ---- PROPERTY VIEWS ----
create policy "views_anon_insert" on property_views for insert with check (true);
create policy "views_admin_read"  on property_views for select
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- ---- COMPARE LISTS ----
create policy "compare_user_crud" on compare_lists for all using (auth.uid() = user_id);

-- =============================================================
-- STORAGE BUCKETS  (run separately or via Supabase Dashboard)
-- =============================================================

-- Run these individually in the Supabase Storage tab or via JS client:
--
--   supabase.storage.createBucket('property-images', { public: true, fileSizeLimit: 10485760 });
--   supabase.storage.createBucket('agent-avatars',   { public: true, fileSizeLimit: 2097152  });
--   supabase.storage.createBucket('agency-assets',   { public: true, fileSizeLimit: 5242880  });
--   supabase.storage.createBucket('documents',       { public: false });

-- =============================================================
-- MIGRATION TRACKING  (for Week 2 WP → Supabase import)
-- =============================================================

create table migration_log (
  id            uuid primary key default uuid_generate_v4(),
  entity_type   text not null,             -- 'property', 'agent', etc.
  wp_id         int,
  supabase_id   uuid,
  status        text not null default 'pending',  -- pending / done / error
  error_message text,
  migrated_at   timestamptz
);

-- =============================================================
-- DONE
-- =============================================================
-- Next steps:
--   1. Run this file in Supabase SQL Editor
--   2. Create storage buckets (see comments above)
--   3. Add your SUPABASE_URL + SUPABASE_ANON_KEY to .env
--   4. Week 2: run the WordPress migration script (migrate-wp.js)
