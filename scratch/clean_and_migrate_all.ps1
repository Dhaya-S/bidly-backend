# Run direct SQL cleanup on Neon Postgres for broken 404 mock test fixtures
$pgPassword = "npg_BLlnutq2yzo0"
$env:PGPASSWORD = $pgPassword
$pgHost = "ep-fragrant-union-ayftexwy-pooler.c-5.us-east-2.aws.neon.tech"
$pgUser = "neondb_owner"
$pgDb = "neondb"

Write-Host "Cleaning broken mock test fixtures from listings table..." -ForegroundColor Cyan

# SQL script to deactivate test fixtures and broken 404 mock URLs
$sql = @"
UPDATE listings 
SET status = 'DELETED', reel_url = NULL 
WHERE reel_url LIKE '%test-reel-video.mp4%' 
   OR reel_url LIKE '%phase3_6_drone_reel.mp4%' 
   OR reel_url LIKE '%test_reel%'
   OR title LIKE '%Phase 3.5 Test%'
   OR title LIKE '%Phase 3.6 4K Camera Drone Reel%';

CREATE INDEX IF NOT EXISTS idx_listings_active_reels ON listings(status, created_at DESC) WHERE reel_url IS NOT NULL;
"@

$sqlFile = "$env:TEMP\cleanup_reels.sql"
Set-Content -Path $sqlFile -Value $sql

& psql -h $pgHost -U $pgUser -d $pgDb -f $sqlFile

Write-Host "Cleanup completed!" -ForegroundColor Green
