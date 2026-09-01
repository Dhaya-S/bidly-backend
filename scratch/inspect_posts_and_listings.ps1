$baseUrl = "http://localhost:8081/api"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.11 - INSPECTING POSTS & LISTINGS FOR TEST DATA" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Fetch Posts Feed
$postsRes = Invoke-RestMethod -Uri "$baseUrl/posts?page=0&size=50" -Method Get
$posts = $postsRes.data
Write-Host "`nFetched $($posts.Count) Community Posts:" -ForegroundColor Yellow

$testPosts = @()
foreach ($p in $posts) {
    $mediaUrl = $p.mediaUrl
    $content = $p.content
    $id = $p.id
    if ($mediaUrl -match "test-drone" -or $mediaUrl -match "phase3_6" -or $mediaUrl -match "test-reel" -or $content -match "Phase 3.5" -or $content -match "Phase 3.6") {
        $testPosts += $p
        Write-Host "  [TEST POST] id=$id content='$content' mediaUrl='$mediaUrl'" -ForegroundColor Red
    } else {
        Write-Host "  [CLEAN POST] id=$id content='$content' mediaUrl='$mediaUrl'" -ForegroundColor Green
    }
}

$color = if ($testPosts.Count -gt 0) { "Red" } else { "Green" }
Write-Host "`nTotal Test Posts Found: $($testPosts.Count)" -ForegroundColor $color
