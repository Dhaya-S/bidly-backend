-- V3__user_setup_preferences.sql
-- Adds support for identity verification (DigiLocker), location, search radius, and category interests

ALTER TABLE users ADD COLUMN IF NOT EXISTS is_identity_verified BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS identity_provider VARCHAR(50);
ALTER TABLE users ADD COLUMN IF NOT EXISTS trust_score INT DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS address TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS pincode VARCHAR(20);
ALTER TABLE users ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE users ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE users ADD COLUMN IF NOT EXISTS search_radius_km INT DEFAULT 5;
ALTER TABLE users ADD COLUMN IF NOT EXISTS onboarding_completed BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS user_interests (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_name VARCHAR(100) NOT NULL,
    PRIMARY KEY (user_id, category_name)
);
