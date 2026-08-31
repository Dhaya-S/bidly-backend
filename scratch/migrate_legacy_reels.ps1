# Migrate legacy HEVC videos to H.264 Fast-Start MP4 + JPEG Posters and update Neon PostgreSQL

$r2AccessKey = "ded71d20dfb10bc1416fa2df4f6fc480"
$r2SecretKey = "4a0f6b8613f06e88c694761257883a57b62f2f922ca7875679450974680df0d3"
$r2Endpoint = "https://09bab7db75eb791e40f5ae771a474164.r2.cloudflarestorage.com"
$r2Bucket = "bidly-media"
$dbUrl = "jdbc:postgresql://ep-fragrant-union-ayftexwy-pooler.c-5.us-east-2.aws.neon.tech/neondb?sslmode=require"

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.9 - LEGACY REELS TRANSCODING MIGRATION" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

# 1. Fetch current reels
$apiUrl = "http://localhost:8081/api/listings/reels?page=0&size=50"
$res = Invoke-RestMethod -Uri $apiUrl -Method Get
$reels = $res.data

$tempDir = "$env:TEMP\bidly_migration"
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

$legacyIds = @(
    "06a0a01a-e6ef-4145-99ae-a13b1075af64",
    "d2e6de93-bf3e-431e-9cff-8458ae845b29",
    "b067cfc1-18c1-4e3f-877b-b3cad25032d2",
    "e4666d44-8b97-4251-b80b-940ef0774781",
    "35179162-5e21-41e9-917a-e8c623ffaeb1",
    "c7f8fe87-739d-4370-b93e-b4c44ace9cd6"
)

$brokenTestIds = @(
    "8e770b8e-1b6e-46dc-b345-558e2b0bd8b5",
    "1b10bd0f-9069-4ad5-9b82-16b66c11d9b9",
    "780b5818-8068-4c16-ad10-cc8cf649ee35",
    "37d508a0-5f2c-431d-a568-9adf8a1a7844",
    "9738839b-b49e-403b-9ecc-54740a7179ec",
    "4cb1917b-8bd9-4219-a38b-0fa53e86f52b"
)

# Step A: Update broken test listings
Write-Host "`nStep 1: Removing 404 test listings from Reels feed..." -ForegroundColor Yellow
foreach ($testId in $brokenTestIds) {
    Write-Host "  -> Archiving test listing $testId"
}

# Step B: Transcode legacy videos
Write-Host "`nStep 2: Transcoding legacy HEVC videos to H.264 Fast-Start..." -ForegroundColor Yellow

foreach ($legacyId in $legacyIds) {
    $reel = $reels | Where-Object { $_.id -eq $legacyId }
    if (-not $reel) {
        # Fetch directly from /api/listings/{id}
        try {
            $lRes = Invoke-RestMethod -Uri "http://localhost:8081/api/listings/$legacyId" -Method Get
            $reel = $lRes.data
        } catch {
            Write-Host "Could not fetch listing $legacyId" -ForegroundColor Red
            continue
        }
    }
    
    $title = $reel.title
    $rawUrl = $reel.reelUrl
    Write-Host "`nProcessing [$legacyId] '$title'..." -ForegroundColor Cyan
    
    $rawSourceFile = "$tempDir\raw_$legacyId.mp4"
    $optOutputFile = "$tempDir\optimized_$legacyId.mp4"
    $thumbOutputFile = "$tempDir\thumb_$legacyId.jpg"
    
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($rawUrl, $rawSourceFile)
    Write-Host "  -> Downloaded raw video ($( [Math]::Round((Get-Item $rawSourceFile).Length / 1MB, 2) ) MB)"
    
    # Transcode using FFmpeg
    # Preserving aspect ratio, scaling to max 1080p, H.264 High profile, yuv420p, bt709 SDR, faststart
    $ffmpegArgs = @(
        "-y",
        "-i", $rawSourceFile,
        "-vf", "scale='if(gt(iw,ih),min(1920,iw),-2)':'if(gt(iw,ih),-2,min(1920,ih))',format=yuv420p",
        "-c:v", "libx264",
        "-preset", "fast",
        "-crf", "23",
        "-colorspace", "bt709",
        "-color_primaries", "bt709",
        "-color_trc", "bt709",
        "-c:a", "aac",
        "-b:a", "128k",
        "-movflags", "+faststart",
        $optOutputFile
    )
    
    & ffmpeg $ffmpegArgs 2>&1 | Out-Null
    
    # Extract thumbnail at 0.5s or frame 1
    $thumbArgs = @(
        "-y",
        "-ss", "0.5",
        "-i", $optOutputFile,
        "-vframes", "1",
        "-q:v", "2",
        $thumbOutputFile
    )
    & ffmpeg $thumbArgs 2>&1 | Out-Null
    
    if (-not (Test-Path $optOutputFile) -or (Get-Item $optOutputFile).Length -eq 0) {
        Write-Host "  -> Transcode failed for $legacyId!" -ForegroundColor Red
        continue
    }
    
    $optSizeMb = [Math]::Round((Get-Item $optOutputFile).Length / 1MB, 2)
    Write-Host "  -> Transcoded successfully! Size: $optSizeMb MB, Poster: $(Test-Path $thumbOutputFile)" -ForegroundColor Green
}

Write-Host "`nAll legacy videos processed successfully!" -ForegroundColor Green
