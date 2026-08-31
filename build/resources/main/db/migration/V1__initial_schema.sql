-- ============================================================
-- V1__initial_schema.sql
-- Bidly initial database schema
-- ============================================================

-- Users
CREATE TABLE users (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    phone       VARCHAR(20) NOT NULL,
    name        VARCHAR(100),
    avatar_url  TEXT,
    city        VARCHAR(100),
    state       VARCHAR(100),
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT  uk_users_phone UNIQUE (phone)
);

-- OTP Verifications
CREATE TABLE otp_verifications (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    phone       VARCHAR(20) NOT NULL,
    otp_code    VARCHAR(10) NOT NULL,
    expires_at  TIMESTAMPTZ NOT NULL,
    verified    BOOLEAN     NOT NULL DEFAULT FALSE,
    attempts    INT         NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_otp_phone ON otp_verifications(phone);

-- Categories
CREATE TABLE categories (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(100) NOT NULL,
    icon_url    TEXT,
    parent_id   UUID        REFERENCES categories(id),
    sort_order  INT         NOT NULL DEFAULT 0,
    is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Listings
CREATE TABLE listings (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    title        VARCHAR(200) NOT NULL,
    description  TEXT,
    price        NUMERIC(12,2) NOT NULL,
    category_id  UUID         NOT NULL REFERENCES categories(id),
    seller_id    UUID         NOT NULL REFERENCES users(id),
    city         VARCHAR(100),
    state        VARCHAR(100),
    condition    VARCHAR(20)  NOT NULL DEFAULT 'USED',
    status       VARCHAR(20)  NOT NULL DEFAULT 'ACTIVE',
    views_count  BIGINT       NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_listings_seller   ON listings(seller_id);
CREATE INDEX idx_listings_category ON listings(category_id);
CREATE INDEX idx_listings_status   ON listings(status);
CREATE INDEX idx_listings_city     ON listings(city);

-- Listing Media (images/videos from Cloudflare R2)
CREATE TABLE listing_media (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    listing_id  UUID        NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    url         TEXT        NOT NULL,
    type        VARCHAR(10) NOT NULL DEFAULT 'IMAGE',
    sort_order  INT         NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_media_listing ON listing_media(listing_id);

-- Saved Listings (favorites)
CREATE TABLE saved_listings (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    listing_id  UUID        NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT  uk_saved_user_listing UNIQUE (user_id, listing_id)
);

-- Seed default categories
INSERT INTO categories (name, icon_url, sort_order) VALUES
    ('Vehicles',          NULL, 1),
    ('Property',          NULL, 2),
    ('Electronics',       NULL, 3),
    ('Furniture',         NULL, 4),
    ('Fashion',           NULL, 5),
    ('Books & Education', NULL, 6),
    ('Sports & Hobbies',  NULL, 7),
    ('Jobs',              NULL, 8),
    ('Services',          NULL, 9),
    ('Others',            NULL, 10);
