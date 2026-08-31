$baseUrl = "http://localhost:8081/api"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.10 - STEP 6: CLOUDFLARE R2 RANGE & STREAMING TEST" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# Fetch active reels from feed API
$reelsRes = Invoke-RestMethod -Uri "$baseUrl/listings/reels?page=0&size=5" -Method Get
$reels = $reelsRes.data

foreach ($reel in $reels) {
    $id = $reel.id
    $title = $reel.title
    $url = $reel.reelUrl
    Write-Host "`nTesting Reel [$id] '$title'..." -ForegroundColor Yellow
    Write-Host "  URL: $url" -ForegroundColor Gray

    # 1. Test standard GET HEAD / Initial probe
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $head = curl.exe -s -I "$url"
    $sw.Stop()
    $ttfb = $sw.ElapsedMilliseconds
    Write-Host "  -> TTFB (HEAD): $ttfb ms" -ForegroundColor Green

    # 2. Test HTTP 206 Range Request (First 1MB)
    $rangeSw = [System.Diagnostics.Stopwatch]::StartNew()
    $rangeHeaders = curl.exe -s -I -H "Range: bytes=0-1048575" "$url"
    $rangeSw.Stop()
    $rangeTtfb = $rangeSw.ElapsedMilliseconds
    Write-Host "  -> TTFB (Range 0-1MB): $rangeTtfb ms" -ForegroundColor Green

    $statusLine = ($rangeHeaders | Select-String "HTTP/").Line
    $acceptRanges = ($rangeHeaders | Select-String "accept-ranges:").Line
    $contentRange = ($rangeHeaders | Select-String "content-range:").Line
    $contentType = ($rangeHeaders | Select-String "content-type:").Line
    $contentLength = ($rangeHeaders | Select-String "content-length:").Line

    Write-Host "  -> Status: $statusLine" -ForegroundColor Cyan
    Write-Host "  -> $acceptRanges"
    Write-Host "  -> $contentRange"
    Write-Host "  -> $contentType"
    Write-Host "  -> $contentLength"
}
