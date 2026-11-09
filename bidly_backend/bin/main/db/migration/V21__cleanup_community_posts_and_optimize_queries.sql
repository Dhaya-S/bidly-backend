-- ====================================================================
-- Flyway Migration V21: Clean orphan test posts & optimize queries
-- ====================================================================

-- 1. Remove likes associated with test posts
DELETE FROM post_likes WHERE post_id IN (
    SELECT p.id FROM community_posts p
    LEFT JOIN listings l ON p.listing_id = l.id
    WHERE p.media_url LIKE '%test-drone%'
       OR p.media_url LIKE '%phase3_6%'
       OR p.media_url LIKE '%test-reel%'
       OR p.content LIKE '%Phase 3.5%'
       OR p.content LIKE '%Phase 3.6%'
       OR (p.listing_id IS NOT NULL AND (l.id IS NULL OR l.status = 'DELETED'))
);

-- 2. Delete test community posts referencing deleted fixtures or test files
DELETE FROM community_posts p
WHERE p.media_url LIKE '%test-drone%'
   OR p.media_url LIKE '%phase3_6%'
   OR p.media_url LIKE '%test-reel%'
   OR p.content LIKE '%Phase 3.5%'
   OR p.content LIKE '%Phase 3.6%'
   OR (p.listing_id IS NOT NULL AND p.listing_id IN (SELECT id FROM listings WHERE status = 'DELETED'));

-- 3. Composite index for fast community and global post feed ordering
CREATE INDEX IF NOT EXISTS idx_community_posts_feed 
ON community_posts(community_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_community_posts_global 
ON community_posts(created_at DESC) WHERE community_id IS NULL;
