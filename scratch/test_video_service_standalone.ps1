# scratch/test_video_service_standalone.ps1
$ErrorActionPreference = "Stop"

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.7 VIDEO PROCESSING SERVICE STANDALONE TEST" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

$tempDir = Join-Path $env:TEMP "bidly_test_videos"
if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

function Test-FFmpegPipeline {
    param(
        [string]$Name,
        [string]$Resolution,
        [int]$DurationSec,
        [bool]$WithAudio
    )

    Write-Host "Testing Case: $Name ($Resolution, ${DurationSec}s, Audio=$WithAudio)..." -ForegroundColor Yellow

    $srcPath = Join-Path $tempDir "${Name}_src.mp4"
    $outPath = Join-Path $tempDir "${Name}_opt.mp4"
    $thumbPath = Join-Path $tempDir "${Name}_thumb.jpg"

    if (Test-Path $srcPath) { Remove-Item $srcPath -Force }
    if (Test-Path $outPath) { Remove-Item $outPath -Force }
    if (Test-Path $thumbPath) { Remove-Item $thumbPath -Force }

    # 1. Generate test video
    if ($WithAudio) {
        $genArgs = @(
            "-y", "-f", "lavfi", "-i", "testsrc=duration=${DurationSec}:size=${Resolution}:rate=30",
            "-f", "lavfi", "-i", "sine=frequency=1000:duration=${DurationSec}",
            "-c:v", "libx264", "-c:a", "aac", "-b:a", "128k",
            $srcPath
        )
    } else {
        $genArgs = @(
            "-y", "-f", "lavfi", "-i", "testsrc=duration=${DurationSec}:size=${Resolution}:rate=30",
            "-c:v", "libx264", "-an",
            $srcPath
        )
    }

    $genProcess = Start-Process -FilePath "ffmpeg" -ArgumentList $genArgs -NoNewWindow -PassThru -Wait
    if ($genProcess.ExitCode -ne 0) { throw "Failed to generate test video $Name" }
    $srcSize = (Get-Item $srcPath).Length
    Write-Host "  -> Generated Source: $([Math]::Round($srcSize/1KB, 1)) KB" -ForegroundColor DarkGray

    # 2. Probe with ffprobe
    $probeOut = & ffprobe -v error -show_entries format=duration,size,bit_rate:stream=index,codec_type,codec_name,width,height -of json $srcPath | ConvertFrom-Json
    $srcW = $probeOut.streams[0].width
    $srcH = $probeOut.streams[0].height
    Write-Host "  -> Probed: ${srcW}x${srcH}, format=$($probeOut.format.format_name)" -ForegroundColor DarkGray

    # 3. Calculate target resolution (1080p max, preserve aspect, even dimensions)
    $scaleFactor = 1.0
    if ($srcH -ge $srcW) {
        if ($srcW -gt 1080 -or $srcH -gt 1920) {
            $scaleFactor = [Math]::Min(1080.0 / $srcW, 1920.0 / $srcH)
        }
    } else {
        if ($srcW -gt 1920 -or $srcH -gt 1080) {
            $scaleFactor = [Math]::Min(1920.0 / $srcW, 1080.0 / $srcH)
        }
    }
    $targetW = [int]([Math]::Round($srcW * $scaleFactor) / 2) * 2
    $targetH = [int]([Math]::Round($srcH * $scaleFactor) / 2) * 2
    if ($targetW -lt 2) { $targetW = 2 }
    if ($targetH -lt 2) { $targetH = 2 }
    Write-Host "  -> Target Resolution: ${targetW}x${targetH} (scaleFactor=$([Math]::Round($scaleFactor, 3)))" -ForegroundColor Green

    # 4. Transcode to fast-start H.264
    $transArgs = @(
        "-y", "-i", $srcPath,
        "-c:v", "libx264", "-preset", "fast", "-crf", "23", "-maxrate", "3500k", "-bufsize", "7000k", "-pix_fmt", "yuv420p",
        "-vf", "scale=${targetW}:${targetH}:flags=lanczos"
    )
    if ($WithAudio) {
        $transArgs += @("-c:a", "aac", "-b:a", "128k", "-ac", "2")
    } else {
        $transArgs += @("-an")
    }
    $transArgs += @("-movflags", "+faststart", $outPath)

    $transProcess = Start-Process -FilePath "ffmpeg" -ArgumentList $transArgs -NoNewWindow -PassThru -Wait
    if ($transProcess.ExitCode -ne 0) { throw "Failed to transcode video $Name" }
    $optSize = (Get-Item $outPath).Length
    Write-Host "  -> Transcoded Size: $([Math]::Round($optSize/1KB, 1)) KB" -ForegroundColor Green

    # 5. Generate Thumbnail
    $thumbArgs = @(
        "-y", "-ss", "00:00:01.000", "-i", $outPath,
        "-vframes", "1", "-vf", "scale=${targetW}:${targetH}", "-q:v", "2",
        $thumbPath
    )
    $thumbProcess = Start-Process -FilePath "ffmpeg" -ArgumentList $thumbArgs -NoNewWindow -PassThru -Wait
    if ($thumbProcess.ExitCode -ne 0) { throw "Failed to generate thumbnail $Name" }
    $thumbSize = (Get-Item $thumbPath).Length
    Write-Host "  -> Thumbnail Size: $([Math]::Round($thumbSize/1KB, 1)) KB" -ForegroundColor Green

    # 6. Verify faststart (moov atom before mdat)
    $bytes = [System.IO.File]::ReadAllBytes($outPath)
    $prefix = [System.Text.Encoding]::ASCII.GetString($bytes[0..([Math]::Min(65536, $bytes.Length-1))])
    $moovIdx = $prefix.IndexOf("moov")
    $mdatIdx = $prefix.IndexOf("mdat")

    if ($moovIdx -ge 0 -and ($mdatIdx -lt 0 -or $moovIdx -lt $mdatIdx)) {
        Write-Host "  -> Fast-Start Verified: PASS (moov atom at position $moovIdx, before mdat at $mdatIdx)" -ForegroundColor Green
    } else {
        throw "Fast-start verification failed for $Name"
    }

    # Cleanup
    Remove-Item $srcPath, $outPath, $thumbPath -Force
    Write-Host "  -> Cleanup: PASS`n" -ForegroundColor DarkGray
}

# Test Suite Cases
Test-FFmpegPipeline -Name "Portrait_720p" -Resolution "720x1280" -DurationSec 3 -WithAudio $true
Test-FFmpegPipeline -Name "Portrait_1080p" -Resolution "1080x1920" -DurationSec 3 -WithAudio $true
Test-FFmpegPipeline -Name "Portrait_4K" -Resolution "2160x3840" -DurationSec 2 -WithAudio $true
Test-FFmpegPipeline -Name "Landscape_4K" -Resolution "3840x2160" -DurationSec 2 -WithAudio $true
Test-FFmpegPipeline -Name "Silent_Video" -Resolution "720x1280" -DurationSec 2 -WithAudio $false
Test-FFmpegPipeline -Name "Small_SD" -Resolution "480x640" -DurationSec 2 -WithAudio $true

Write-Host "========================================================" -ForegroundColor Green
Write-Host "ALL STANDALONE VIDEO PIPELINE TESTS PASSED (100%)" -ForegroundColor Green
Write-Host "========================================================`n" -ForegroundColor Green
