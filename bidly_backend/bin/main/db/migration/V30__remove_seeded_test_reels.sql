-- V30: Remove old seeded test reels (from V23) that reference non-existent R2 video files.
-- These reels have reel_url pointing to hardcoded keys that were never uploaded to Cloudflare R2,
-- so they return 404s and cannot be played. Only real user-uploaded reels should remain.

-- The seeded reels used exactly these 3 video keys:
--   listings/reels/48ed0968-1aaf-4886-881d-f353e8ffc356.mp4
--   listings/reels/b0e08cf6-47c2-43cd-873a-6d5d04120cb1.mp4
--   listings/reels/4b6f283b-7a46-4b2a-9841-45f99afbbeab.mp4

-- Delete listing_media entries first (FK constraint)
DELETE FROM listing_media WHERE listing_id IN (
    SELECT id FROM listings WHERE reel_url IN (
        'listings/reels/48ed0968-1aaf-4886-881d-f353e8ffc356.mp4',
        'listings/reels/b0e08cf6-47c2-43cd-873a-6d5d04120cb1.mp4',
        'listings/reels/4b6f283b-7a46-4b2a-9841-45f99afbbeab.mp4'
    )
);

-- Delete the seeded listing entries themselves
DELETE FROM listings WHERE reel_url IN (
    'listings/reels/48ed0968-1aaf-4886-881d-f353e8ffc356.mp4',
    'listings/reels/b0e08cf6-47c2-43cd-873a-6d5d04120cb1.mp4',
    'listings/reels/4b6f283b-7a46-4b2a-9841-45f99afbbeab.mp4'
);
