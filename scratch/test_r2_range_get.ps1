$baseUrl = "http://localhost:8081/api"
$reelsRes = Invoke-RestMethod -Uri "$baseUrl/listings/reels?page=0&size=5" -Method Get
$reels = $reelsRes.data

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.10 - STEP 6: VERIFYING HTTP 206 RANGE STREAMING" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

foreach ($reel in $reels) {
    $id = $reel.id
    $title = $reel.title
    $url = $reel.reelUrl
    Write-Host "`nTesting Reel [$id] '$title'..." -ForegroundColor Yellow

    # Perform GET Range request
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $headerFile = "$env:TEMP\r2_headers_$id.txt"
    $dumpFile = "$env:TEMP\r2_chunk_$id.bin"
    & curl.exe -s -r 0-1048575 -D $headerFile -o $dumpFile $url
    $sw.Stop()
    $latency = $sw.ElapsedMilliseconds

    $headers = Get-Content $headerFile
    $statusLine = ($headers | Select-String "HTTP/").Line
    $acceptRanges = ($headers | Select-String "accept-ranges:").Line
    $contentRange = ($headers | Select-String "content-range:").Line
    $contentType = ($headers | Select-String "content-type:").Line
    $contentLength = ($headers | Select-String "content-length:").Line
    $chunkSize = (Get-Item $dumpFile).Length

    Write-Host "  -> Latency: $latency ms" -ForegroundColor Green
    Write-Host "  -> Status: $statusLine" -ForegroundColor Cyan
    Write-Host "  -> $acceptRanges"
    Write-Host "  -> $contentRange"
    Write-Host "  -> $contentType"
    Write-Host "  -> $contentLength"
    Write-Host "  -> Downloaded Chunk Size: $chunkSize bytes" -ForegroundColor Green

    Remove-Item $headerFile -ErrorAction SilentlyContinue
    Remove-Item $dumpFile -ErrorAction SilentlyContinue
}
