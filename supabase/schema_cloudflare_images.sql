-- =============================================================
--  Cloudflare Images Integration
--  Run AFTER schema.sql + schema_additions.sql
--
--  Replaces Supabase Storage paths with Cloudflare Images IDs.
--
--  Cloudflare Images delivery URL pattern:
--    https://imagedelivery.net/{ACCOUNT_HASH}/{IMAGE_ID}/{VARIANT}
--
--  Variants to create in CF Dashboard → Images → Variants:
--    thumbnail  → 400×300  fit=cover  quality=85
--    card       → 800×600  fit=cover  quality=85
--    hero       → 1600×900 fit=cover  quality=90
--    avatar     → 200×200  fit=cover  quality=90
--    public     → original (max 1920px wide, quality=85)
--
--  How uploads will work (Week 3 Edge Function):
--    1. Client requests a one-time upload URL from Edge Function
--    2. Edge Function calls: POST /accounts/{id}/images/v1 (direct creator upload)
--    3. CF returns { id: "abc123xyz" }
--    4. Edge Function saves id to property_images.cf_image_id
--    5. Front-end constructs URL from id + variant
-- =============================================================

-- =============================================================
-- UPDATE property_images — swap storage_path for cf_image_id
-- =============================================================

alter table property_images
  add column if not exists cf_image_id text,           -- Cloudflare Images image ID
  add column if not exists cf_account_hash text;       -- optional: store per-row if multi-account

-- Drop old Supabase Storage column (only run after migration is complete)
-- alter table property_images drop column if exists storage_path;

-- Helper: build the full CF delivery URL
create or replace function cf_image_url(image_id text, variant text default 'card')
returns text language sql immutable as $$
  -- Replace YOUR_ACCOUNT_HASH with your actual Cloudflare account hash
  select 'https://imagedelivery.net/YOUR_ACCOUNT_HASH/' || image_id || '/' || variant;
$$;

-- =============================================================
-- UPDATE project_images — same change
-- =============================================================

alter table project_images
  add column if not exists cf_image_id text;

-- =============================================================
-- UPDATE floor_plans — swap storage_path for cf_image_id
-- =============================================================

alter table floor_plans
  add column if not exists cf_image_id text;

-- =============================================================
-- UPDATE agents — avatar_url becomes cf_image_id
-- =============================================================

alter table agents
  add column if not exists cf_avatar_id text;         -- CF Images ID for agent avatar

-- =============================================================
-- UPDATE developers — logo and cover
-- =============================================================

alter table developers
  add column if not exists cf_logo_id  text,          -- CF Images ID for logo
  add column if not exists cf_cover_id text;          -- CF Images ID for cover photo

-- =============================================================
-- UPDATE agencies — logo
-- =============================================================

alter table agencies
  add column if not exists cf_logo_id text;

-- =============================================================
-- UPDATE projects — cover image
-- =============================================================

alter table projects
  add column if not exists cf_cover_id text;

-- =============================================================
-- CLOUDFLARE IMAGES CONFIG TABLE
-- Stores your CF account settings (read by Edge Functions)
-- =============================================================

create table if not exists cf_images_config (
  id            uuid primary key default uuid_generate_v4(),
  account_id    text not null,           -- Cloudflare Account ID
  account_hash  text not null,           -- For delivery URLs (imagedelivery.net/{hash})
  api_token     text,                    -- Store encrypted / use Cloudflare secret
  delivery_base text not null default 'https://imagedelivery.net',
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

-- Only admins can read/write config
alter table cf_images_config enable row level security;
create policy "cf_config_admin_only" on cf_images_config for all
  using (exists (select 1 from profiles where id = auth.uid() and role = 'admin'));

-- =============================================================
-- VARIANT REFERENCE TABLE (documents what variants exist in CF)
-- =============================================================

create table if not exists cf_image_variants (
  id          uuid primary key default uuid_generate_v4(),
  name        text not null unique,     -- 'thumbnail', 'card', 'hero', 'avatar', 'public'
  width       int,
  height      int,
  fit         text,                     -- 'cover', 'contain', 'scale-down'
  quality     int,
  usage       text,                     -- where this variant is used
  created_at  timestamptz not null default now()
);

insert into cf_image_variants (name, width, height, fit, quality, usage) values
  ('thumbnail', 400,  300,  'cover', 85, 'Search result cards, property grids'),
  ('card',      800,  600,  'cover', 85, 'Property detail page gallery thumbnails'),
  ('hero',      1600, 900,  'cover', 90, 'Property detail hero / full-screen gallery'),
  ('avatar',    200,  200,  'cover', 90, 'Agent & developer profile photos'),
  ('public',    1920, null, 'cover', 85, 'Original download, floor plans');

-- =============================================================
-- VIEW: properties with ready-to-use CF image URLs
-- =============================================================

create or replace view properties_with_images as
select
  p.*,
  loc.city,
  loc.province,
  loc.full_address,
  loc.latitude,
  loc.longitude,
  -- Thumbnail URL (for search/grid)
  case
    when img.cf_image_id is not null
    then cf_image_url(img.cf_image_id, 'thumbnail')
    else img.url      -- fallback to direct URL
  end as thumbnail_url,
  -- Card URL (for detail page)
  case
    when img.cf_image_id is not null
    then cf_image_url(img.cf_image_id, 'card')
    else img.url
  end as card_url,
  -- Hero URL (for full-screen)
  case
    when img.cf_image_id is not null
    then cf_image_url(img.cf_image_id, 'hero')
    else img.url
  end as hero_url
from properties p
left join property_locations loc on loc.property_id = p.id
left join property_images img    on img.property_id = p.id and img.is_primary = true
where p.status = 'active';

-- =============================================================
-- NOTES FOR IMPLEMENTATION (Week 3)
-- =============================================================
--
-- 1. CREATE VARIANTS in Cloudflare Dashboard:
--    → Account → Images → Variants → Add variant (use names above)
--
-- 2. SET UP WORKER / EDGE FUNCTION for secure uploads:
--    POST /api/upload-image
--    Body: { type: 'property' | 'avatar' | 'project', entity_id: uuid }
--    → Calls CF Images API to get a one-time upload URL
--    → Returns { uploadUrl, imageId } to the client
--    → Client uploads directly to CF (no server bandwidth used)
--    → Client calls POST /api/confirm-image with { imageId, entity_id }
--    → Edge Function saves imageId to the correct table
--
-- 3. IN YOUR ASTRO COMPONENTS, replace wsrv.nl with:
--    const imgUrl = `https://imagedelivery.net/${CF_ACCOUNT_HASH}/${cf_image_id}/thumbnail`;
--
-- 4. ENVIRONMENT VARIABLES needed in Cloudflare Pages:
--    CF_ACCOUNT_ID      = your cloudflare account ID
--    CF_ACCOUNT_HASH    = hash used in delivery URLs
--    CF_IMAGES_TOKEN    = API token with Images:Edit permission
--
-- 5. MIGRATION of existing WP images (Week 2):
--    migrate-wp.js will download each WP image and upload to CF Images,
--    storing the returned image ID in property_images.cf_image_id
