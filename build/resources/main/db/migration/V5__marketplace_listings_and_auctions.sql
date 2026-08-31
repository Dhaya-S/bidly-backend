-- V5__marketplace_listings_and_auctions.sql
-- Adds selling_method, bidding fields, locality, and rating to listings table

ALTER TABLE listings ADD COLUMN IF NOT EXISTS selling_method VARCHAR(20) NOT NULL DEFAULT 'DIRECT_BUY';
ALTER TABLE listings ADD COLUMN IF NOT EXISTS starting_bid NUMERIC(12,2);
ALTER TABLE listings ADD COLUMN IF NOT EXISTS current_bid NUMERIC(12,2);
ALTER TABLE listings ADD COLUMN IF NOT EXISTS auction_end_time TIMESTAMPTZ;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS locality VARCHAR(100);
ALTER TABLE listings ADD COLUMN IF NOT EXISTS rating NUMERIC(3,1) DEFAULT 4.5;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS distance_km NUMERIC(5,1) DEFAULT 2.0;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS is_featured BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

CREATE INDEX IF NOT EXISTS idx_listings_method ON listings(selling_method);
CREATE INDEX IF NOT EXISTS idx_listings_featured ON listings(is_featured);
