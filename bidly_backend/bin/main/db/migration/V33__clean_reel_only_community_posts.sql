-- ====================================================================
-- Flyway Migration V33: Clean legacy reel-only community posts
-- ====================================================================

-- 1. Remove likes associated with legacy reel-only posts
DELETE FROM post_likes WHERE post_id IN (
    SELECT p.id FROM community_posts p
    JOIN listings l ON p.listing_id = l.id
    WHERE l.reel_url IS NOT NULL
      AND TRIM(l.reel_url) <> ''
      AND NOT EXISTS (
          SELECT 1 FROM listing_media lm
          WHERE lm.listing_id = l.id
            AND lm.type = 'IMAGE'
            AND lm.url NOT LIKE '%-thumb.jpg%'
      )
);

-- 2. Remove legacy community posts created from reel-only listings
DELETE FROM community_posts p
WHERE p.listing_id IS NOT NULL
  AND p.listing_id IN (
      SELECT l.id FROM listings l
      WHERE l.reel_url IS NOT NULL
        AND TRIM(l.reel_url) <> ''
        AND NOT EXISTS (
            SELECT 1 FROM listing_media lm
            WHERE lm.listing_id = l.id
              AND lm.type = 'IMAGE'
              AND lm.url NOT LIKE '%-thumb.jpg%'
        )
  );

-- 3. Delete any thumbnail entries mistakenly stored in listing_media
DELETE FROM listing_media WHERE url LIKE '%-thumb.jpg%';
