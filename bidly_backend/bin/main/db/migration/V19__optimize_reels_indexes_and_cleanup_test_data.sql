-- Step 1: Cleanup broken test mock fixtures from production Reels feed
UPDATE listings 
SET status = 'DELETED', reel_url = NULL 
WHERE reel_url LIKE '%test-reel-video.mp4%' 
   OR reel_url LIKE '%phase3_6_drone_reel.mp4%' 
   OR reel_url LIKE '%test_reel%'
   OR title LIKE '%Phase 3.5 Test%'
   OR title LIKE '%Phase 3.6 4K Camera Drone Reel%';

-- Step 2: High-performance composite partial index for Reels feed queries
CREATE INDEX IF NOT EXISTS idx_listings_active_reels ON listings(status, created_at DESC) WHERE reel_url IS NOT NULL;
