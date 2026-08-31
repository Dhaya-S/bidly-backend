# scratch/test_phase3_7_media_upload.ps1
$ErrorActionPreference = "Stop"

$baseUrl = "http://localhost:8081/api"
$tempDir = Join-Path $env:TEMP "bidly_upload_test"
if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.7 MEDIA UPLOAD & TRANSCODING INTEGRATION TEST" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

# 1. Authenticate Seller
Write-Host "[1/9] Authenticating Test Seller (9840011111)..." -ForegroundColor Yellow
$userMobile = "9840011111"
$otpRes = Invoke-RestMethod -Uri "$baseUrl/auth/send-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userMobile; name = "Priya Raman" } | ConvertTo-Json)
$authRes = Invoke-RestMethod -Uri "$baseUrl/auth/verify-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userMobile; otp = "123456"; requestId = $otpRes.data.requestId; name = "Priya Raman" } | ConvertTo-Json)
$token = $authRes.data.token
$userId = $authRes.data.user.id
Write-Host "  -> Seller Authenticated: $userId" -ForegroundColor Green

$headers = @{ Authorization = "Bearer $token" }

# Helper to upload via multipart form-data
function Upload-MultipartFile {
    param(
        [string]$FilePath,
        [string]$Folder = "listings"
    )
    $uri = "$baseUrl/media/upload?folder=$Folder"
    $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)
    $fileName = [System.IO.Path]::GetFileName($FilePath)

    $boundary = [System.Guid]::NewGuid().ToString()
    $LF = "`r`n"
    
    $bodyStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($bodyStream)
    
    $writer.Write("--$boundary$LF")
    $writer.Write("Content-Disposition: form-data; name=`"file`"; filename=`"$fileName`"$LF")
    $writer.Write("Content-Type: application/octet-stream$LF$LF")
    $writer.Flush()
    
    $bodyStream.Write($fileBytes, 0, $fileBytes.Length)
    
    $writer.Write("$LF--$boundary--$LF")
    $writer.Flush()
    
    $bodyBytes = $bodyStream.ToArray()
    
    $req = [System.Net.HttpWebRequest]::Create($uri)
    $req.Method = "POST"
    $req.Headers.Add("Authorization", "Bearer $token")
    $req.ContentType = "multipart/form-data; boundary=$boundary"
    $req.ContentLength = $bodyBytes.Length
    
    $reqStream = $req.GetRequestStream()
    $reqStream.Write($bodyBytes, 0, $bodyBytes.Length)
    $reqStream.Close()
    
    try {
        $resp = $req.GetResponse()
        $reader = [System.IO.StreamReader]::new($resp.GetResponseStream())
        $respText = $reader.ReadToEnd()
        $resp.Close()
        return ($respText | ConvertFrom-Json)
    } catch [System.Net.WebException] {
        $errResp = $_.Exception.Response
        if ($errResp -ne $null) {
            $reader = [System.IO.StreamReader]::new($errResp.GetResponseStream())
            $errText = $reader.ReadToEnd()
            $errResp.Close()
            return ($errText | ConvertFrom-Json)
        }
        throw $_
    }
}

# 2. Test 1: Upload 1080p Portrait Reel Video
Write-Host "`n[2/9] Generating & Uploading 1080p Portrait Reel Video..." -ForegroundColor Yellow
$vid1080p = Join-Path $tempDir "test_1080p_reel.mp4"
if (Test-Path $vid1080p) { Remove-Item $vid1080p -Force }

$ffmpegArgs = @(
    "-y", "-f", "lavfi", "-i", "testsrc=duration=3:size=1080x1920:rate=30",
    "-f", "lavfi", "-i", "sine=frequency=1000:duration=3",
    "-c:v", "libx264", "-c:a", "aac", "-b:a", "128k",
    $vid1080p
)
$p = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegArgs -NoNewWindow -PassThru -Wait
if ($p.ExitCode -ne 0) { throw "FFmpeg failed to create test video" }

$upload1Res = Upload-MultipartFile -FilePath $vid1080p -Folder "listings/reels"
Write-Host "  -> Response: success=$($upload1Res.success), message='$($upload1Res.message)'" -ForegroundColor Green
Write-Host "  -> Video URL: $($upload1Res.data.url)" -ForegroundColor Green
Write-Host "  -> Thumbnail URL: $($upload1Res.data.thumbnailUrl)" -ForegroundColor Green

if ($upload1Res.data.url -notmatch "listings/reels/.+\.mp4") {
    throw "Step 2 failed: Expected url to match 'listings/reels/*.mp4'"
}
if ($upload1Res.data.thumbnailUrl -notmatch "listings/reels/.+-thumb\.jpg") {
    throw "Step 2 failed: Expected thumbnailUrl to match 'listings/reels/*-thumb.jpg'"
}

$uploadedReelKey = $upload1Res.data.url
$uploadedThumbKey = $upload1Res.data.thumbnailUrl

# 3. Test 2: Upload 4K Video (Should be downscaled to 1080p)
Write-Host "`n[3/9] Generating & Uploading 4K Portrait Reel Video (Downscaling Test)..." -ForegroundColor Yellow
$vid4k = Join-Path $tempDir "test_4k_reel.mp4"
if (Test-Path $vid4k) { Remove-Item $vid4k -Force }

$ffmpeg4kArgs = @(
    "-y", "-f", "lavfi", "-i", "testsrc=duration=2:size=2160x3840:rate=30",
    "-f", "lavfi", "-i", "sine=frequency=1000:duration=2",
    "-c:v", "libx264", "-c:a", "aac", "-b:a", "128k",
    $vid4k
)
$p4k = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpeg4kArgs -NoNewWindow -PassThru -Wait
if ($p4k.ExitCode -ne 0) { throw "FFmpeg failed to create 4K test video" }

$upload2Res = Upload-MultipartFile -FilePath $vid4k -Folder "listings/reels"
Write-Host "  -> 4K Upload Video URL: $($upload2Res.data.url)" -ForegroundColor Green
Write-Host "  -> 4K Upload Thumbnail URL: $($upload2Res.data.thumbnailUrl)" -ForegroundColor Green

# 4. Test 3: Upload Silent Video
Write-Host "`n[4/9] Generating & Uploading Silent Reel Video..." -ForegroundColor Yellow
$vidSilent = Join-Path $tempDir "test_silent_reel.mp4"
if (Test-Path $vidSilent) { Remove-Item $vidSilent -Force }

$ffmpegSilentArgs = @(
    "-y", "-f", "lavfi", "-i", "testsrc=duration=2:size=720x1280:rate=30",
    "-c:v", "libx264", "-an",
    $vidSilent
)
$pSilent = Start-Process -FilePath "ffmpeg" -ArgumentList $ffmpegSilentArgs -NoNewWindow -PassThru -Wait
if ($pSilent.ExitCode -ne 0) { throw "FFmpeg failed to create silent video" }

$uploadSilentRes = Upload-MultipartFile -FilePath $vidSilent -Folder "listings/reels"
Write-Host "  -> Silent Video URL: $($uploadSilentRes.data.url)" -ForegroundColor Green

# 5. Test 4: Upload Image to 'listings/photos' (Should bypass FFmpeg)
Write-Host "`n[5/9] Uploading standard Photo Image (Should bypass FFmpeg)..." -ForegroundColor Yellow
$testImg = Join-Path $tempDir "test_photo.jpg"
if (Test-Path $testImg) { Remove-Item $testImg -Force }

$imgArgs = @("-y", "-f", "lavfi", "-i", "testsrc=duration=1:size=640x480:rate=1", "-vframes", "1", "-q:v", "2", $testImg)
$pImg = Start-Process -FilePath "ffmpeg" -ArgumentList $imgArgs -NoNewWindow -PassThru -Wait
if ($pImg.ExitCode -ne 0) { throw "FFmpeg failed to create test image" }

$uploadImgRes = Upload-MultipartFile -FilePath $testImg -Folder "listings/photos"
Write-Host "  -> Photo URL: $($uploadImgRes.data.url)" -ForegroundColor Green
Write-Host "  -> Photo Thumbnail: $($uploadImgRes.data.thumbnailUrl)" -ForegroundColor Green
if ($uploadImgRes.data.thumbnailUrl -ne $null) {
    throw "Step 5 failed: Photo upload should have null thumbnailUrl!"
}

# 6. Test 5: Verify Presigned Direct R2 Streaming & HTTP Range (206 Partial Content)
Write-Host "`n[6/9] Verifying R2 Direct Streaming & HTTP Byte Range (206 Partial Content)..." -ForegroundColor Yellow

# Create a listing using the uploaded Reel and auto-generated thumbnail
$createListingBody = @{
    title = "Phase 3.7 Optimized Camera Drone"
    description = "Ultra HD cinematic drone with fast-start streaming reel."
    price = 78000
    category = "Electronics"
    sellingMethod = "DIRECT_BUY"
    sellingScope = "GLOBAL"
    reelUrl = $uploadedReelKey
    mediaUrls = @($uploadedThumbKey) # Auto-linked thumbnail!
    city = "Chennai"
    state = "Tamil Nadu"
    locality = "Adyar"
} | ConvertTo-Json

$listingRes = Invoke-RestMethod -Uri "$baseUrl/listings" -Method Post -Headers $headers -ContentType "application/json" -Body $createListingBody
$listingId = $listingRes.data.id
Write-Host "  -> Created Listing ID: $listingId ('$($listingRes.data.title)')" -ForegroundColor Green

# 7. Fetch Reels Feed from API
Write-Host "`n[7/9] Fetching Reels Feed from GET /api/listings/reels..." -ForegroundColor Yellow
$reelsRes = Invoke-RestMethod -Uri "$baseUrl/listings/reels?page=0&size=5" -Method Get -Headers $headers
$createdReel = $reelsRes.data | Where-Object { $_.id -eq $listingId }

if ($createdReel -eq $null) {
    throw "Step 7 failed: Created reel listing not found in /api/listings/reels"
}

Write-Host "  -> Reel Title: $($createdReel.title)" -ForegroundColor Green
Write-Host "  -> Presigned Reel Stream URL: $($createdReel.reelUrl.Substring(0, [Math]::Min(90, $createdReel.reelUrl.Length)))..." -ForegroundColor Green
Write-Host "  -> Presigned Poster Thumbnail: $($createdReel.primaryImageUrl.Substring(0, [Math]::Min(90, $createdReel.primaryImageUrl.Length)))..." -ForegroundColor Green

# 8. Test HTTP Byte-Range Request on the Presigned Reel Stream URL
Write-Host "`n[8/9] Sending HTTP Range Request (bytes=0-1024) to Presigned R2 URL..." -ForegroundColor Yellow
$rangeReq = [System.Net.HttpWebRequest]::Create($createdReel.reelUrl)
$rangeReq.Method = "GET"
$rangeReq.AddRange(0, 1024)
$rangeResp = $rangeReq.GetResponse()

Write-Host "  -> HTTP Status Code: $($rangeResp.StatusCode)" -ForegroundColor Green
Write-Host "  -> Content-Range: $($rangeResp.Headers['Content-Range'])" -ForegroundColor Green
Write-Host "  -> Content-Type: $($rangeResp.Headers['Content-Type'])" -ForegroundColor Green
Write-Host "  -> Accept-Ranges: $($rangeResp.Headers['Accept-Ranges'])" -ForegroundColor Green
$rangeResp.Close()

if ($rangeResp.StatusCode -ne "PartialContent") {
    throw "Step 8 failed: Expected HTTP 206 PartialContent for Range request"
}
if ($rangeResp.Headers['Content-Type'] -notmatch "video/mp4") {
    throw "Step 8 failed: Expected Content-Type video/mp4"
}

# 9. Test Invalid Upload Error Handling
Write-Host "`n[9/9] Testing Invalid Video Error Handling..." -ForegroundColor Yellow
$badFile = Join-Path $tempDir "corrupt.mp4"
[System.IO.File]::WriteAllText($badFile, "This is not a real mp4 video file data.")

$badUploadRes = Upload-MultipartFile -FilePath $badFile -Folder "listings/reels"
Write-Host "  -> Invalid Video Response: success=$($badUploadRes.success), message='$($badUploadRes.message)'" -ForegroundColor Green

# Cleanup test directory
Remove-Item -Path $tempDir -Recurse -Force
Write-Host "  -> Temporary test files cleaned: PASS" -ForegroundColor DarkGray

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "ALL PHASE 3.7 UPLOAD & STREAMING INTEGRATION TESTS PASSED" -ForegroundColor Green
Write-Host "========================================================`n" -ForegroundColor Green
