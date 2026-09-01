$baseUrl = "http://localhost:8081/api"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.11 - ACCURACY & PERFORMANCE SPEED TEST (5 RUNS)" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

$postsTimes = @()
for ($i = 1; $i -le 5; $i++) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $res = Invoke-RestMethod -Uri "$baseUrl/posts?page=0&size=10" -Method Get
    $sw.Stop()
    $postsTimes += $sw.ElapsedMilliseconds
    $ms = $sw.ElapsedMilliseconds
    $count = $res.data.Count
    Write-Host "Run $i - ${ms}ms (Items: $count)"
}

$avg = ($postsTimes | Measure-Object -Average).Average
Write-Host "`nAverage /api/posts Latency: $avg ms" -ForegroundColor Green

Write-Host "`nTesting /api/listings/reels (5 Runs):" -ForegroundColor Cyan
$reelsTimes = @()
for ($i = 1; $i -le 5; $i++) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $res = Invoke-RestMethod -Uri "$baseUrl/listings/reels?page=0&size=10" -Method Get
    $sw.Stop()
    $reelsTimes += $sw.ElapsedMilliseconds
    $ms = $sw.ElapsedMilliseconds
    $count = $res.data.Count
    Write-Host "Run $i - ${ms}ms (Items: $count)"
}

$avgReels = ($reelsTimes | Measure-Object -Average).Average
Write-Host "`nAverage /api/listings/reels Latency: $avgReels ms" -ForegroundColor Green
