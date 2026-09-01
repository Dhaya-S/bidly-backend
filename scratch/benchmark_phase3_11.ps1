$baseUrl = "http://localhost:8081/api"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.11 - BENCHMARKING APIS & TEST DATA VERIFICATION" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Warm-up / Test /api/posts latency
Write-Host "`nTesting GET /api/posts?page=0&size=10..." -ForegroundColor Yellow
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$postsRes = Invoke-RestMethod -Uri "$baseUrl/posts?page=0&size=10" -Method Get
$sw.Stop()
$postsElapsed = $sw.ElapsedMilliseconds

Write-Host "  -> First Call Latency: $postsElapsed ms" -ForegroundColor $(if ($postsElapsed -lt 1500) { "Green" } else { "Yellow" })
Write-Host "  -> Success: $($postsRes.success)"
Write-Host "  -> Items returned: $($postsRes.data.Count)"

# 2. Second invocation of /api/posts (warm cache/connection)
$sw.Restart()
$postsRes2 = Invoke-RestMethod -Uri "$baseUrl/posts?page=0&size=10" -Method Get
$sw.Stop()
$postsElapsed2 = $sw.ElapsedMilliseconds
Write-Host "  -> Warm Latency: $postsElapsed2 ms" -ForegroundColor $(if ($postsElapsed2 -lt 600) { "Green" } else { "Yellow" })

# 3. Check for any remaining test items in /api/posts
$testFound = 0
foreach ($p in $postsRes.data) {
    $mediaUrl = $p.mediaUrl
    $content = $p.content
    $id = $p.id
    if ($mediaUrl -match "test-drone" -or $mediaUrl -match "phase3_6" -or $mediaUrl -match "test-reel" -or $content -match "Phase 3.5" -or $content -match "Phase 3.6") {
        $testFound++
        Write-Host "  [TEST ITEM FOUND] id=$id content='$content'" -ForegroundColor Red
    }
}
Write-Host "  -> Test fixtures in posts: $testFound (Target: 0)" -ForegroundColor $(if ($testFound -eq 0) { "Green" } else { "Red" })

# 4. Test /api/listings/reels latency
Write-Host "`nTesting GET /api/listings/reels?page=0&size=10..." -ForegroundColor Yellow
$sw.Restart()
$reelsRes = Invoke-RestMethod -Uri "$baseUrl/listings/reels?page=0&size=10" -Method Get
$sw.Stop()
$reelsElapsed = $sw.ElapsedMilliseconds
Write-Host "  -> Latency: $reelsElapsed ms" -ForegroundColor $(if ($reelsElapsed -lt 500) { "Green" } else { "Yellow" })
Write-Host "  -> Items returned: $($reelsRes.data.Count)"

# 5. Check test items in /api/listings/reels
$testReels = 0
foreach ($r in $reelsRes.data) {
    $url = $r.reelUrl
    $title = $r.title
    if ($url -match "test-drone" -or $url -match "phase3_6" -or $url -match "test-reel" -or $title -match "Phase 3.5" -or $title -match "Phase 3.6") {
        $testReels++
    }
}
Write-Host "  -> Test fixtures in reels: $testReels (Target: 0)" -ForegroundColor $(if ($testReels -eq 0) { "Green" } else { "Red" })

# 6. Test /api/communities latency
Write-Host "`nTesting GET /api/communities?page=0&size=10..." -ForegroundColor Yellow
$sw.Restart()
$commRes = Invoke-RestMethod -Uri "$baseUrl/communities?page=0&size=10" -Method Get
$sw.Stop()
$commElapsed = $sw.ElapsedMilliseconds
Write-Host "  -> Latency: $commElapsed ms" -ForegroundColor $(if ($commElapsed -lt 500) { "Green" } else { "Yellow" })
Write-Host "  -> Items returned: $($commRes.data.Count)"

# 7. Test /api/listings/featured latency
Write-Host "`nTesting GET /api/listings/featured..." -ForegroundColor Yellow
$sw.Restart()
$featRes = Invoke-RestMethod -Uri "$baseUrl/listings/featured" -Method Get
$sw.Stop()
$featElapsed = $sw.ElapsedMilliseconds
Write-Host "  -> Latency: $featElapsed ms" -ForegroundColor $(if ($featElapsed -lt 500) { "Green" } else { "Yellow" })
Write-Host "  -> Items returned: $($featRes.data.Count)"
