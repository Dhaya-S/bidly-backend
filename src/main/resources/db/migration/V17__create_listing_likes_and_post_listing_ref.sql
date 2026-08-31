-- V17__create_listing_likes_and_post_listing_ref.sql
-- 1. Create listing_likes table for persistent likes on Listings and Reels
CREATE TABLE IF NOT EXISTS listing_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    listing_id UUID NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_listing_likes_user_listing UNIQUE (user_id, listing_id)
);

CREATE INDEX IF NOT EXISTS idx_listing_likes_listing_id ON listing_likes(listing_id);
CREATE INDEX IF NOT EXISTS idx_listing_likes_user_id ON listing_likes(user_id);

-- 2. Add listing_id foreign key to community_posts for Instagram-style rich media posts
ALTER TABLE community_posts ADD COLUMN IF NOT EXISTS listing_id UUID REFERENCES listings(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_posts_listing ON community_posts(listing_id);
