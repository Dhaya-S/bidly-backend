-- V15: Add primary_image_url column and performance indexes on listings

-- 1. Add primary_image_url to listings table for zero-join listing card queries
ALTER TABLE listings ADD COLUMN IF NOT EXISTS primary_image_url TEXT;

-- 2. Backfill primary_image_url from the first listing_media record for existing active listings
UPDATE listings l
SET primary_image_url = (
    SELECT lm.url
    FROM listing_media lm
    WHERE lm.listing_id = l.id
    ORDER BY lm.sort_order ASC, lm.created_at ASC
    LIMIT 1
)
WHERE l.primary_image_url IS NULL;

-- 3. Composite indexes for high-frequency queries
CREATE INDEX IF NOT EXISTS idx_listings_status_created ON listings(status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listings_seller_status ON listings(seller_id, status);
CREATE INDEX IF NOT EXISTS idx_listings_method_status ON listings(selling_method, status);
