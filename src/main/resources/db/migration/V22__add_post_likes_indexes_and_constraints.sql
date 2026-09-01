-- ====================================================================
-- Flyway Migration V22: Add indexes & constraints for post likes
-- ====================================================================

-- 1. Index on post_likes(post_id) for fast count and post lookup
CREATE INDEX IF NOT EXISTS idx_post_likes_post_id ON post_likes(post_id);

-- 2. Index on post_likes(user_id, post_id) for fast user like check
CREATE INDEX IF NOT EXISTS idx_post_likes_user_post ON post_likes(user_id, post_id);

-- 3. Ensure likes_count column exists on community_posts with default 0
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'community_posts' AND column_name = 'likes_count'
    ) THEN
        ALTER TABLE community_posts ADD COLUMN likes_count INT NOT NULL DEFAULT 0;
    END IF;
END $$;
