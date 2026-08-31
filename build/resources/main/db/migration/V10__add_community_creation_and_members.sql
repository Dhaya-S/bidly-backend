-- V10__add_community_creation_and_members.sql
-- Adds community creation details, membership roles, and default communities

ALTER TABLE communities ADD COLUMN IF NOT EXISTS created_by UUID REFERENCES users(id) ON DELETE SET NULL;
ALTER TABLE communities ADD COLUMN IF NOT EXISTS category VARCHAR(100);
ALTER TABLE communities ADD COLUMN IF NOT EXISTS address VARCHAR(255);
ALTER TABLE communities ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE communities ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE communities ADD COLUMN IF NOT EXISTS radius_km INT DEFAULT 5;
ALTER TABLE communities ADD COLUMN IF NOT EXISTS rules TEXT;
ALTER TABLE communities ADD COLUMN IF NOT EXISTS recent_activity_text TEXT;
ALTER TABLE communities ADD COLUMN IF NOT EXISTS recent_activity_time TIMESTAMPTZ DEFAULT NOW();

CREATE TABLE IF NOT EXISTS community_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    community_id UUID NOT NULL REFERENCES communities(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(30) NOT NULL DEFAULT 'MEMBER',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uk_community_user UNIQUE (community_id, user_id)
);
ALTER TABLE community_members ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
ALTER TABLE community_members ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
CREATE INDEX IF NOT EXISTS idx_community_members_community ON community_members(community_id);
CREATE INDEX IF NOT EXISTS idx_community_members_user ON community_members(user_id);

-- Insert authentic default communities if none exist
INSERT INTO communities (id, name, description, type, category, city, state, address, radius_km, members_count, recent_activity_text, recent_activity_time, is_active)
SELECT 
    'a1111111-1111-1111-1111-111111111111'::uuid,
    'IIT Madras Campus Buy & Sell',
    'Official student marketplace for campus electronics, books, and gear.',
    'COLLEGE',
    'Electronics',
    'Chennai',
    'Tamil Nadu',
    'IIT Madras Campus, Sardar Patel Road, Chennai',
    5,
    1280,
    'MacBook Air M2 -> auction starts at ₹48,000',
    NOW() - INTERVAL '2 minutes',
    TRUE
WHERE NOT EXISTS (SELECT 1 FROM communities WHERE name = 'IIT Madras Campus Buy & Sell');

INSERT INTO communities (id, name, description, type, category, city, state, address, radius_km, members_count, recent_activity_text, recent_activity_time, is_active)
SELECT 
    'a2222222-2222-2222-2222-222222222222'::uuid,
    'Velachery Residents',
    'Neighborhood community for local buy and sell in Velachery & surrounding areas.',
    'NEIGHBORHOOD',
    'Appliances',
    'Chennai',
    'Tamil Nadu',
    'Velachery Main Road, Chennai',
    10,
    640,
    'Sony 55" TV available for ₹18,000',
    NOW() - INTERVAL '15 minutes',
    TRUE
WHERE NOT EXISTS (SELECT 1 FROM communities WHERE name = 'Velachery Residents');

INSERT INTO communities (id, name, description, type, category, city, state, address, radius_km, members_count, recent_activity_text, recent_activity_time, is_active)
SELECT 
    'a3333333-3333-3333-3333-333333333333'::uuid,
    'Photography Enthusiasts',
    'Second-hand cameras, lenses, lighting gear, and auction hub.',
    'INTEREST',
    'Electronics',
    'Chennai',
    'Tamil Nadu',
    'T. Nagar, Chennai',
    25,
    420,
    'Canon 5D auction tonight 8PM!',
    NOW() - INTERVAL '1 hour',
    TRUE
WHERE NOT EXISTS (SELECT 1 FROM communities WHERE name = 'Photography Enthusiasts');

INSERT INTO communities (id, name, description, type, category, city, state, address, radius_km, members_count, recent_activity_text, recent_activity_time, is_active)
SELECT 
    'a4444444-4444-4444-4444-444444444444'::uuid,
    'Chennai Gamers Hub',
    'Consoles, gaming laptops, graphic cards, and game disc exchange.',
    'INTEREST',
    'Electronics',
    'Chennai',
    'Tamil Nadu',
    'Nungambakkam, Chennai',
    50,
    890,
    'PS5 + 3 games - ₹35,000 fixed price',
    NOW() - INTERVAL '3 hours',
    TRUE
WHERE NOT EXISTS (SELECT 1 FROM communities WHERE name = 'Chennai Gamers Hub');
