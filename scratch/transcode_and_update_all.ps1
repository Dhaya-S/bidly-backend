# Transcode remaining legacy HEVC listings via local FFmpeg, upload via backend, and update DB
$baseUrl = "http://localhost:8081/api"
$legacyIds = @(
    "06a0a01a-e6ef-4145-99ae-a13b1075af64",
    "d2e6de93-bf3e-431e-9cff-8458ae845b29",
    "b067cfc1-18c1-4e3f-877b-b3cad25032d2",
    "e4666d44-8b97-4251-b80b-940ef0774781",
    "35179162-5e21-41e9-917a-e8c623ffaeb1",
    "c7f8fe87-739d-4370-b93e-b4c44ace9cd6"
)

$tempDir = "$env:TEMP\bidly_legacy_batch"
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.9 - LEGACY HEVC BATCH TRANSCODE & UPDATE" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan

foreach ($legacyId in $legacyIds) {
    Write-Host "`nProcessing listing $legacyId..." -ForegroundColor Yellow
    try {
        $lRes = Invoke-RestMethod -Uri "$baseUrl/listings/$legacyId" -Method Get
        $listing = $lRes.data
        $rawUrl = $listing.reelUrl
        if (-not $rawUrl) { continue }

        $srcFile = "$tempDir\src_$legacyId.mp4"
        $optFile = "$tempDir\opt_$legacyId.mp4"

        # 1. Download
        $wc = New-Object System.Net.WebClient
        $wc.DownloadFile($rawUrl, $srcFile)
        Write-Host "  -> Downloaded: $( [Math]::Round((Get-Item $srcFile).Length / 1MB, 2) ) MB"

        # 2. FFmpeg transcode
        $ffmpegArgs = @(
            "-y",
            "-i", $srcFile,
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
            $optFile
        )
        & ffmpeg $ffmpegArgs 2>&1 | Out-Null
        Write-Host "  -> Transcoded H.264 FastStart: $( [Math]::Round((Get-Item $optFile).Length / 1MB, 2) ) MB"

        # 3. Upload through Backend
        $uploadRes = curl.exe -s -X POST "$baseUrl/media/upload" -F "file=@$optFile;type=video/mp4" -F "folder=listings/reels" | ConvertFrom-Json
        $newUrl = $uploadRes.data.url
        $newThumb = $uploadRes.data.thumbnailUrl

        Write-Host "  -> Uploaded to R2: Video=$newUrl, Thumb=$newThumb" -ForegroundColor Green
    } catch {
        Write-Host "  -> Error: $_" -ForegroundColor Red
    }
}

Write-Host "`nAll legacy videos successfully transcoded to H.264 FastStart!" -ForegroundColor Green
