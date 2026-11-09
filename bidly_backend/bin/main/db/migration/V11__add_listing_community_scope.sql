-- V11__add_listing_community_scope.sql
-- Adds community_id and community_name to listings table for community-only publishing
ALTER TABLE listings ADD COLUMN IF NOT EXISTS community_id UUID REFERENCES communities(id) ON DELETE SET NULL;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS community_name VARCHAR(150);

CREATE INDEX IF NOT EXISTS idx_listings_community_id ON listings(community_id);
