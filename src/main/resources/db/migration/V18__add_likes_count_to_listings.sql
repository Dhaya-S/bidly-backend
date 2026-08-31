-- V18__add_likes_count_to_listings.sql
ALTER TABLE listings ADD COLUMN IF NOT EXISTS likes_count INT NOT NULL DEFAULT 0;
