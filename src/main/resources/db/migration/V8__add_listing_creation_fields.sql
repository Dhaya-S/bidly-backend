-- V8__add_listing_creation_fields.sql
-- Adds subcategory, purchase date, damage details, selling scope, and reel url to listings

ALTER TABLE listings ADD COLUMN IF NOT EXISTS subcategory VARCHAR(100);
ALTER TABLE listings ADD COLUMN IF NOT EXISTS purchase_date VARCHAR(50);
ALTER TABLE listings ADD COLUMN IF NOT EXISTS has_damage BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS damage_details TEXT;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS selling_scope VARCHAR(50) NOT NULL DEFAULT 'GLOBAL';
ALTER TABLE listings ADD COLUMN IF NOT EXISTS target_radius_km INT;
ALTER TABLE listings ADD COLUMN IF NOT EXISTS bid_increment NUMERIC(12,2);
ALTER TABLE listings ADD COLUMN IF NOT EXISTS reel_url TEXT;
