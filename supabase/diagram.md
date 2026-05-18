# Philippine Properties — Database Diagram

> Open this file in VS Code with the **Mermaid Preview** extension (`Ctrl+Shift+P` → "Mermaid Preview"),  
> or paste any diagram block into **https://mermaid.live** for a shareable image.

---

## 1. System Data Flow (Level 0 + Level 1)

```mermaid
flowchart TD
    subgraph USERS["👥 User Types"]
        A1["🧑 Buyer / Guest"]
        A2["🏢 Agent / Seller"]
        A3["👑 Admin"]
    end

    subgraph SITE["🌐 Philippine Properties Website"]
        B1["Search & Browse Listings"]
        B2["Property Detail Page"]
        B3["Agent Profile Page"]
        B4["List a Property"]
        B5["Schedule Viewing / Open House"]
        B6["Contact / Inquiry Form"]
        B7["Save to Favourites"]
        B8["Set Property Alert"]
        B9["Admin Dashboard"]
    end

    subgraph DB["🗄️ Supabase Database"]
        C1["properties"]
        C2["property_locations"]
        C3["property_images"]
        C4["property_amenities"]
        C5["agents + profiles"]
        C6["inquiries"]
        C7["viewings"]
        C8["open_houses"]
        C9["saved_properties"]
        C10["property_alerts"]
        C11["property_views"]
        C12["agent_reviews"]
    end

    subgraph STORAGE["🪣 Supabase Storage"]
        S1["property-images bucket"]
        S2["agent-avatars bucket"]
        S3["documents bucket (private)"]
    end

    subgraph EDGE["⚡ Edge Functions"]
        E1["send-inquiry"]
        E2["notify-alert"]
        E3["confirm-viewing"]
    end

    A1 -->|browse| B1
    A1 -->|view| B2
    A1 -->|submit| B6
    A1 -->|save| B7
    A1 -->|subscribe| B8
    A1 -->|book| B5

    A2 -->|create listing| B4
    A2 -->|manage| B9

    A3 -->|full access| B9

    B1 -->|search_properties()| C1
    B2 -->|read| C1
    B2 -->|read| C2
    B2 -->|read| C3
    B2 -->|read| C5
    B2 -->|log visit| C11
    B3 -->|read| C5
    B3 -->|read| C12
    B4 -->|write| C1
    B4 -->|write| C2
    B4 -->|upload| S1
    B5 -->|write| C7
    B5 -->|write| C8
    B6 -->|write| C6
    B6 -->|trigger| E1
    B7 -->|write| C9
    B8 -->|write| C10
    B8 -->|trigger| E2

    E1 -->|email agent| A2
    E2 -->|email subscriber| A1
    E3 -->|email confirmation| A1

    style USERS fill:#fff7ed,stroke:#ea580c,color:#000
    style SITE fill:#eff6ff,stroke:#3b82f6,color:#000
    style DB fill:#f0fdf4,stroke:#22c55e,color:#000
    style STORAGE fill:#fdf4ff,stroke:#a855f7,color:#000
    style EDGE fill:#fefce8,stroke:#eab308,color:#000
```

---

## 2. Entity Relationship Diagram (ERD)

```mermaid
erDiagram

    PROFILES {
        uuid    id          PK
        text    full_name
        text    phone
        text    avatar_url
        enum    role        "buyer|seller|agent|admin"
        bool    is_verified
    }

    AGENTS {
        uuid    id          PK  "FK → profiles"
        uuid    agency_id   FK
        text    license_number
        text[]  specializations
        text[]  service_areas
        text    whatsapp_number
        numeric rating_avg
        int     rating_count
        int     total_sold
    }

    AGENCIES {
        uuid    id          PK
        text    name
        text    slug
        text    logo_url
        bool    is_verified
        bool    is_active
    }

    PROPERTIES {
        uuid    id          PK
        text    slug
        text    title
        text    description
        enum    listing_type  "For Sale|For Rent|Pre-selling|Lease to Own"
        enum    property_type "House & Lot|Condo|Townhouse|Apartment|Land & Lot|Commercial"
        enum    status        "active|sold|rented|pending|draft"
        numeric price
        numeric price_per_sqm
        int     bedrooms
        int     bathrooms
        numeric floor_area
        numeric lot_area
        int     parking_spaces
        enum    furnished     "Unfurnished|Semi|Fully"
        uuid    agent_id    FK
        uuid    agency_id   FK
        uuid    owner_id    FK
        bool    is_featured
        bool    is_verified
        bool    accepts_pag_ibig
        int     view_count
        int     inquiry_count
        int     save_count
        int     wp_post_id  "migration ref"
    }

    PROPERTY_LOCATIONS {
        uuid    id          PK
        uuid    property_id FK
        text    full_address
        text    barangay
        text    city
        text    province
        text    region
        numeric latitude
        numeric longitude
    }

    PROPERTY_IMAGES {
        uuid    id          PK
        uuid    property_id FK
        text    storage_path
        text    url
        bool    is_primary
        int     sort_order
    }

    AMENITIES {
        uuid    id          PK
        text    name
        text    icon
        enum    category    "building|unit|outdoor|nearby"
    }

    PROPERTY_AMENITIES {
        uuid    property_id PK  "FK → properties"
        uuid    amenity_id  PK  "FK → amenities"
    }

    SAVED_PROPERTIES {
        uuid    id          PK
        uuid    user_id     FK
        uuid    property_id FK
        ts      created_at
    }

    INQUIRIES {
        uuid    id          PK
        uuid    property_id FK
        uuid    agent_id    FK
        uuid    sender_id   FK
        text    sender_name
        text    sender_email
        text    sender_phone
        text    message
        enum    status      "new|read|replied|closed"
    }

    VIEWINGS {
        uuid    id          PK
        uuid    property_id FK
        uuid    agent_id    FK
        uuid    user_id     FK
        text    guest_name
        text    guest_email
        date    preferred_date
        time    preferred_time
        enum    status      "pending|confirmed|cancelled|completed"
    }

    OPEN_HOUSES {
        uuid    id          PK
        uuid    property_id FK
        uuid    agent_id    FK
        date    event_date
        time    start_time
        time    end_time
        int     max_attendees
    }

    OPEN_HOUSE_RSVPS {
        uuid    id            PK
        uuid    open_house_id FK
        uuid    user_id       FK
        text    name
        text    email
        text    phone
    }

    PROPERTY_ALERTS {
        uuid    id           PK
        text    email
        uuid    user_id      FK
        enum    listing_type
        enum    property_type
        text    city
        numeric min_price
        numeric max_price
        int     min_bedrooms
        bool    is_active
    }

    NEWSLETTER_SUBSCRIBERS {
        uuid    id        PK
        text    email
        uuid    user_id   FK
        bool    is_active
    }

    AGENT_REVIEWS {
        uuid    id           PK
        uuid    agent_id     FK
        uuid    reviewer_id  FK
        uuid    property_id  FK
        int     rating       "1–5"
        text    comment
    }

    PROPERTY_VIEWS {
        uuid    id          PK
        uuid    property_id FK
        uuid    user_id     FK
        text    ip_hash
        text    referrer
        ts      viewed_at
    }

    MIGRATION_LOG {
        uuid    id          PK
        text    entity_type
        int     wp_id
        uuid    supabase_id
        text    status
    }

    %% --- Relationships ---

    PROFILES         ||--o|  AGENTS            : "can be an"
    AGENCIES         ||--o{  AGENTS            : "employs"
    AGENTS           ||--o{  PROPERTIES        : "lists"
    AGENCIES         ||--o{  PROPERTIES        : "owns"

    PROPERTIES       ||--||  PROPERTY_LOCATIONS : "located at"
    PROPERTIES       ||--o{  PROPERTY_IMAGES    : "has photos"
    PROPERTIES       ||--o{  PROPERTY_AMENITIES : "offers"
    AMENITIES        ||--o{  PROPERTY_AMENITIES : "tagged in"

    PROFILES         ||--o{  SAVED_PROPERTIES   : "saves"
    PROPERTIES       ||--o{  SAVED_PROPERTIES   : "saved by"

    PROPERTIES       ||--o{  INQUIRIES          : "receives"
    AGENTS           ||--o{  INQUIRIES          : "handles"
    PROFILES         ||--o{  INQUIRIES          : "sends"

    PROPERTIES       ||--o{  VIEWINGS           : "booked for"
    AGENTS           ||--o{  VIEWINGS           : "manages"
    PROFILES         ||--o{  VIEWINGS           : "books"

    PROPERTIES       ||--o{  OPEN_HOUSES        : "hosts"
    AGENTS           ||--o{  OPEN_HOUSES        : "runs"
    OPEN_HOUSES      ||--o{  OPEN_HOUSE_RSVPS   : "attended by"
    PROFILES         ||--o{  OPEN_HOUSE_RSVPS   : "RSVPs"

    PROFILES         ||--o{  PROPERTY_ALERTS    : "subscribes"
    PROFILES         ||--o{  NEWSLETTER_SUBSCRIBERS : "subscribes"

    AGENTS           ||--o{  AGENT_REVIEWS      : "reviewed in"
    PROFILES         ||--o{  AGENT_REVIEWS      : "writes"

    PROPERTIES       ||--o{  PROPERTY_VIEWS     : "tracked by"
```

---

## 3. Role & Access Summary

```mermaid
flowchart LR
    subgraph ANON["🌐 Guest / Anonymous"]
        R1["✅ Browse active listings"]
        R2["✅ View property detail"]
        R3["✅ Submit inquiry"]
        R4["✅ Book a viewing"]
        R5["✅ RSVP open house"]
        R6["✅ Set property alert"]
        R7["✅ Subscribe newsletter"]
    end

    subgraph BUYER["👤 Logged-in Buyer"]
        R8["✅ All guest actions"]
        R9["✅ Save favourites"]
        R10["✅ Compare properties"]
        R11["✅ Write agent review"]
        R12["✅ View own inquiry history"]
    end

    subgraph AGENT["🏢 Agent"]
        R13["✅ All buyer actions"]
        R14["✅ Create / edit own listings"]
        R15["✅ Upload property photos"]
        R16["✅ Manage viewings & open houses"]
        R17["✅ Read own inquiries"]
        R18["✅ Edit own agent profile"]
    end

    subgraph ADMIN["👑 Admin"]
        R19["✅ Full access to all tables"]
        R20["✅ Feature / verify listings"]
        R21["✅ Manage agencies & agents"]
        R22["✅ View analytics & logs"]
        R23["✅ Run migration scripts"]
    end
```

---

## 4. Migration Path (WP → Supabase)

```mermaid
flowchart LR
    WP["WordPress\n(current)"] -->|wp-json REST API| SCRIPT["migrate-wp.js\n(Week 2 script)"]
    SCRIPT -->|INSERT| PROPS["properties"]
    SCRIPT -->|INSERT| LOCS["property_locations"]
    SCRIPT -->|upload| IMGS["Supabase Storage\n(property-images)"]
    SCRIPT -->|INSERT| IMG_ROWS["property_images"]
    SCRIPT -->|INSERT| LOG["migration_log\n(track status)"]
    IMGS -->|public URL| IMG_ROWS
```
