$baseUrl = "http://localhost:8081/api"
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.9 - REELS MEDIA INSPECTION" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# Fetch all reels from /api/listings/reels
$reels = @()
$page = 0
$hasMore = $true

while ($hasMore -and $page -lt 5) {
    $apiUrl = $baseUrl + "/listings/reels?page=" + $page + "&size=10"
    $res = Invoke-RestMethod -Uri $apiUrl -Method Get
    if ($res.data -and $res.data.Count -gt 0) {
        $reels += $res.data
        if ($res.data.Count -lt 10) { $hasMore = $false } else { $page++ }
    } else {
        $hasMore = $false
    }
}

Write-Host "Discovered $($reels.Count) active Reels across pages`n" -ForegroundColor Yellow

$tempDir = "$env:TEMP\bidly_legacy_probe"
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

$classifiedReels = @()

foreach ($reel in $reels) {
    $id = $reel.id
    $title = $reel.title
    $rawUrl = $reel.reelUrl
    
    if (-not $rawUrl) { continue }
    
    $tmpFile = "$tempDir\probe_$id.mp4"
    Write-Host "[$id] '$title'" -ForegroundColor White
    
    try {
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($rawUrl, $tmpFile)
        
        $jsonStr = & ffprobe -v error -show_entries stream=codec_name,profile,pix_fmt,width,height,color_space,color_transfer,color_primaries -of json $tmpFile
        $probe = $jsonStr | ConvertFrom-Json
        
        $vStream = $probe.streams | Where-Object { $_.codec_name -ne "aac" -and $_.codec_name -ne "mp3" } | Select-Object -First 1
        $codec = $vStream.codec_name
        $profile = $vStream.profile
        $pixFmt = $vStream.pix_fmt
        $res = "$($vStream.width)x$($vStream.height)"
        $colorTransfer = $vStream.color_transfer
        
        $bytes = [System.IO.File]::ReadAllBytes($tmpFile)
        $headerStr = [System.Text.Encoding]::ASCII.GetString($bytes[0..[Math]::Min(1024, $bytes.Length - 1)])
        $isFastStart = $headerStr.Contains("moov")
        
        $classification = "OPTIMIZED"
        if ($codec -eq "hevc" -or $codec -eq "h265" -or ($colorTransfer -and $colorTransfer.Contains("smpte2086"))) {
            $classification = "LEGACY_REQUIRES_PROCESSING"
        } elseif ($codec -ne "h264" -or $pixFmt -ne "yuv420p") {
            $classification = "LEGACY_REQUIRES_PROCESSING"
        } elseif (-not $isFastStart) {
            $classification = "LEGACY_REQUIRES_PROCESSING"
        }
        
        Write-Host "  -> Codec: $codec, Profile: $profile, PixFmt: $pixFmt, Res: $res, FastStart: $isFastStart" -ForegroundColor DarkGray
        Write-Host "  -> Classification: $classification" -ForegroundColor $(if ($classification -eq "OPTIMIZED") { "Green" } else { "Red" })
        
        $classifiedReels += [PSCustomObject]@{
            Id = $id
            Title = $title
            ReelUrl = $rawUrl
            Codec = $codec
            PixFmt = $pixFmt
            Classification = $classification
        }
    } catch {
        Write-Host "  -> Error probing: $_" -ForegroundColor Red
    }
}

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  -> Total Probed: $($classifiedReels.Count)"
$optCount = ($classifiedReels | Where-Object { $_.Classification -eq 'OPTIMIZED' }).Count
$legacyCount = ($classifiedReels | Where-Object { $_.Classification -ne 'OPTIMIZED' }).Count
Write-Host "  -> Optimized: $optCount" -ForegroundColor Green
Write-Host "  -> Requires Transcoding: $legacyCount" -ForegroundColor Red
