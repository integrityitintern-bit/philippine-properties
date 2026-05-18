# Cloudflare Images & R2 — Setup Guide

Complete setup from zero. Do these steps in order.

---

## Prerequisites

You already have a Cloudflare account (your Pages site is on it).
If not: sign up free at **cloudflare.com**.

---

## Part 1 — Enable Cloudflare Images

**Cost: $5/month** — includes 100,000 images stored + served.
For a real estate site starting out, this covers everything.

### Step 1 — Go to Cloudflare Dashboard

1. Open **dash.cloudflare.com**
2. Log in
3. On the left sidebar, look for **"Images"**
   - If you don't see it: click your account name (top left) → make sure you're at the **account level**, not a specific domain

### Step 2 — Subscribe to Cloudflare Images

1. Click **Images** in the sidebar
2. Click **"Get Started"** or **"Enable Images"**
3. It will ask for a payment method → enter your card
4. Confirm the $5/month subscription
5. You'll land on the Images dashboard

### Step 3 — Get Your Account Hash

This is the hash used in all image delivery URLs.

1. On the Images dashboard, look at the top — you'll see:
   ```
   Delivery URL: https://imagedelivery.net/YOUR_HASH_HERE/image-id/variant
   ```
2. **Copy that hash** — save it somewhere, you'll need it later
3. Also copy your **Account ID**:
   - Click your account name (top left of dashboard)
   - Right sidebar shows **Account ID** → copy it

---

## Part 2 — Create Image Variants

Variants are the sizes/formats CF will auto-generate when images are requested.

1. In the Images dashboard, click **"Variants"** tab
2. Click **"Add variant"** and create each of these **5 variants**:

### Variant 1: `thumbnail`
| Setting | Value |
|---|---|
| Variant name | `thumbnail` |
| Fit | Scale Down |
| Width | 400 |
| Height | 300 |
| Quality | 85 |
| Metadata | Strip |

### Variant 2: `card`
| Setting | Value |
|---|---|
| Variant name | `card` |
| Fit | Scale Down |
| Width | 800 |
| Height | 600 |
| Quality | 85 |
| Metadata | Strip |

### Variant 3: `hero`
| Setting | Value |
|---|---|
| Variant name | `hero` |
| Fit | Scale Down |
| Width | 1600 |
| Height | 900 |
| Quality | 90 |
| Metadata | Strip |

### Variant 4: `avatar`
| Setting | Value |
|---|---|
| Variant name | `avatar` |
| Fit | Cover |
| Width | 200 |
| Height | 200 |
| Quality | 90 |
| Metadata | Strip |

### Variant 5: `public`
| Setting | Value |
|---|---|
| Variant name | `public` |
| Fit | Scale Down |
| Width | 1920 |
| Height | (leave empty) |
| Quality | 85 |
| Metadata | Strip |

> After creating all 5, your Variants list should show: thumbnail, card, hero, avatar, public

---

## Part 3 — Create API Token for Uploads

This token lets your Edge Function upload images to Cloudflare.

1. Go to **dash.cloudflare.com/profile/api-tokens**
   (or: top-right avatar → "My Profile" → "API Tokens")
2. Click **"Create Token"**
3. Click **"Create Custom Token"**
4. Fill in:
   | Field | Value |
   |---|---|
   | Token name | `philippine-properties-images` |
   | Permissions | Account → Cloudflare Images → Edit |
   | Account Resources | Include → Your account |
5. Click **"Continue to summary"** → **"Create Token"**
6. **COPY THE TOKEN NOW** — it only shows once
   - Save it as `CF_IMAGES_TOKEN` in your notes

---

## Part 4 — Set Up Cloudflare R2 (for private documents)

R2 is for storing private files like property titles, contracts.
**Free tier: 10 GB/month** — plenty for documents.

### Step 1 — Enable R2

1. In Cloudflare dashboard sidebar → click **"R2"**
2. If prompted, enable R2 (free, just needs payment method on file)

### Step 2 — Create the documents bucket

1. Click **"Create bucket"**
2. Name: `pp-documents`
3. Location: **Asia Pacific** (APAC) → closest to Philippines
4. Click **"Create bucket"**
5. Leave it as **private** (default) — no public access

### Step 3 — Create R2 API Tokens

1. Still on R2 page → click **"Manage R2 API Tokens"**
2. Click **"Create API token"**
3. Fill in:
   | Field | Value |
   |---|---|
   | Token name | `pp-r2-documents` |
   | Permissions | Object Read & Write |
   | Specify bucket | pp-documents |
4. Click **"Create API Token"**
5. **Copy and save**:
   - Access Key ID → `CF_R2_ACCESS_KEY_ID`
   - Secret Access Key → `CF_R2_SECRET_ACCESS_KEY`
   - Endpoint URL → `CF_R2_ENDPOINT` (looks like `https://ACCOUNT_ID.r2.cloudflarestorage.com`)

---

## Part 5 — Add Environment Variables

### In Cloudflare Pages (for your live site)

1. Cloudflare Dashboard → **Pages** → your project (`philippine-properties`)
2. Click **Settings** → **Environment variables**
3. Click **"Add variable"** for each:

| Variable Name | Value | Where to find it |
|---|---|---|
| `CF_ACCOUNT_ID` | your account ID | Dashboard top-left |
| `CF_ACCOUNT_HASH` | delivery URL hash | Images dashboard |
| `CF_IMAGES_TOKEN` | API token | Step from Part 3 |
| `CF_R2_ACCESS_KEY_ID` | R2 access key | Part 4 Step 3 |
| `CF_R2_SECRET_ACCESS_KEY` | R2 secret | Part 4 Step 3 |
| `CF_R2_ENDPOINT` | R2 endpoint URL | Part 4 Step 3 |

4. Set **Production** and **Preview** for each variable
5. Click **Save**

### In your local `.env` file

Create or update `C:\Users\Rylle\Desktop\integrity-realty\.env`:

```env
# Cloudflare Images
CF_ACCOUNT_ID=your_account_id_here
CF_ACCOUNT_HASH=your_account_hash_here
CF_IMAGES_TOKEN=your_images_api_token_here

# Cloudflare R2 (documents)
CF_R2_ACCESS_KEY_ID=your_r2_access_key_here
CF_R2_SECRET_ACCESS_KEY=your_r2_secret_here
CF_R2_ENDPOINT=https://YOUR_ACCOUNT_ID.r2.cloudflarestorage.com
CF_R2_BUCKET=pp-documents

# Supabase
PUBLIC_SUPABASE_URL=https://your-project.supabase.co
PUBLIC_SUPABASE_ANON_KEY=your_anon_key_here
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key_here
```

> ⚠️ Add `.env` to `.gitignore` — never commit secrets to git.

---

## Part 6 — Update Database Config

After you have the credentials, run this in Supabase SQL Editor:

```sql
insert into cf_images_config (account_id, account_hash)
values (
  'YOUR_CF_ACCOUNT_ID',
  'YOUR_CF_ACCOUNT_HASH'
);
```

Also update the `cf_image_url()` function in Supabase:

```sql
create or replace function cf_image_url(image_id text, variant text default 'card')
returns text language sql immutable as $$
  select 'https://imagedelivery.net/YOUR_ACCOUNT_HASH/' || image_id || '/' || variant;
$$;
```

Replace `YOUR_ACCOUNT_HASH` with your actual hash.

---

## Part 7 — Test It Works

Upload a test image manually to confirm setup:

1. In Images dashboard → click **"Upload"**
2. Drag any photo
3. After upload, you'll see an **Image ID** (looks like `abc123-def456-...`)
4. Open this URL in your browser:
   ```
   https://imagedelivery.net/YOUR_HASH/THE_IMAGE_ID/thumbnail
   ```
5. If you see the image → ✅ everything is working

---

## Summary — What You Now Have

```
Cloudflare Images
  ├── Variant: thumbnail (400×300) — search cards
  ├── Variant: card (800×600) — property detail
  ├── Variant: hero (1600×900) — full screen lightbox
  ├── Variant: avatar (200×200) — agent/dev photos
  └── Variant: public (1920px) — original download

Cloudflare R2
  └── Bucket: pp-documents (private) — titles, contracts

Environment Variables set in:
  ├── Cloudflare Pages dashboard (live)
  └── .env file (local dev)
```

---

## Next Step — Week 2

Once Supabase is also set up, we write `migrate-wp.js` which:
1. Fetches all properties from WordPress REST API
2. Downloads each image from WordPress
3. Re-uploads to Cloudflare Images
4. Saves the returned `imageId` to Supabase `property_images.cf_image_id`
5. Logs each migration to `migration_log` table
