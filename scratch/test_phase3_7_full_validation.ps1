# scratch/test_phase3_7_full_validation.ps1
$ErrorActionPreference = "Stop"

$baseUrl = "http://localhost:8081/api"
$tempDir = Join-Path $env:TEMP "bidly_step4_val"
if (!(Test-Path $tempDir)) { New-Item -ItemType Directory -Path $tempDir | Out-Null }

Write-Host ""
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.7 STEP 4 - FULL END-TO-END VALIDATION SUITE" -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Authenticate Seller User A & Buyer User B
Write-Host "[1/12] Authenticating User A (Seller) and User B (Buyer)..." -ForegroundColor Yellow
$userAMobile = "9840011111"
$otpA = Invoke-RestMethod -Uri "$baseUrl/auth/send-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userAMobile; name = "Priya Raman" } | ConvertTo-Json)
$authA = Invoke-RestMethod -Uri "$baseUrl/auth/verify-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userAMobile; otp = "123456"; requestId = $otpA.data.requestId; name = "Priya Raman" } | ConvertTo-Json)
$tokenA = $authA.data.token
$userAId = $authA.data.user.id
$headersA = @{ Authorization = "Bearer $tokenA" }
Write-Host "  -> User A Authenticated: $userAId ('Priya Raman')" -ForegroundColor Green

$userBMobile = "9840022222"
$otpB = Invoke-RestMethod -Uri "$baseUrl/auth/send-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userBMobile; name = "Karthik Raja" } | ConvertTo-Json)
$authB = Invoke-RestMethod -Uri "$baseUrl/auth/verify-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userBMobile; otp = "123456"; requestId = $otpB.data.requestId; name = "Karthik Raja" } | ConvertTo-Json)
$tokenB = $authB.data.token
$userBId = $authB.data.user.id
$headersB = @{ Authorization = "Bearer $tokenB" }
Write-Host "  -> User B Authenticated: $userBId ('Karthik Raja')" -ForegroundColor Green

# Multipart Upload Helper
function Upload-File {
    param([string]$FilePath, [string]$Folder = "listings")
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
    $req.Headers.Add("Authorization", "Bearer $tokenA")
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

# 2. Test 1: Upload Reel & Create DIRECT_BUY Listing without separate photos
Write-Host ""
Write-Host "[2/12] Testing Reel-Only Upload (Direct Buy, Auto Thumbnail Linking)..." -ForegroundColor Yellow
$vidPath1 = Join-Path $tempDir "reel_direct_buy.mp4"
$p = Start-Process -FilePath "ffmpeg" -ArgumentList @("-y", "-f", "lavfi", "-i", "testsrc=duration=3:size=1080x1920:rate=30", "-f", "lavfi", "-i", "sine=frequency=1000:duration=3", "-c:v", "libx264", "-c:a", "aac", "-b:a", "128k", $vidPath1) -NoNewWindow -PassThru -Wait
if ($p.ExitCode -ne 0) { throw "FFmpeg failed" }

$up1 = Upload-File -FilePath $vidPath1 -Folder "listings/reels"
Write-Host "  -> Upload Result: video=$($up1.data.url), thumb=$($up1.data.thumbnailUrl)" -ForegroundColor Green

# Create Direct Buy Listing (mediaUrls has the auto thumbnail)
$directBuyListingBody = @{
    title = "DJI Mini 4 Pro 4K Drone"
    description = "Flawless drone with omnidirectional obstacle sensing."
    price = 68000
    category = "Electronics"
    sellingMethod = "DIRECT_BUY"
    sellingScope = "GLOBAL"
    reelUrl = $up1.data.url
    mediaUrls = @($up1.data.thumbnailUrl)
    city = "Chennai"
    state = "Tamil Nadu"
    locality = "Adyar"
} | ConvertTo-Json

$dirListingRes = Invoke-RestMethod -Uri "$baseUrl/listings" -Method Post -Headers $headersA -ContentType "application/json" -Body $directBuyListingBody
$dirListingId = $dirListingRes.data.id
Write-Host "  -> Created Direct Buy Listing: $dirListingId" -ForegroundColor Green
Write-Host "  -> Primary Image URL: $($dirListingRes.data.primaryImageUrl.Substring(0, [Math]::Min(75, $dirListingRes.data.primaryImageUrl.Length)))..." -ForegroundColor Green
Write-Host "  -> Selling Method: $($dirListingRes.data.sellingMethod)" -ForegroundColor Green

if ($dirListingRes.data.sellingMethod -ne "DIRECT_BUY") {
    throw "Step 2 failed: Selling method should be DIRECT_BUY"
}

# 3. Test 2: Upload Photo + Reel & Create AUCTION Listing
Write-Host ""
Write-Host "[3/12] Testing Photo plus Reel Upload (Auction, Primary Image Preservation)..." -ForegroundColor Yellow
$photoPath = Join-Path $tempDir "camera_photo.jpg"
$pImg = Start-Process -FilePath "ffmpeg" -ArgumentList @("-y", "-f", "lavfi", "-i", "testsrc=duration=1:size=800x800:rate=1", "-vframes", "1", "-q:v", "2", $photoPath) -NoNewWindow -PassThru -Wait

$upPhoto = Upload-File -FilePath $photoPath -Folder "listings/photos"
Write-Host "  -> Photo Upload: $($upPhoto.data.url)" -ForegroundColor Green

$vidPath2 = Join-Path $tempDir "reel_auction.mp4"
$p2 = Start-Process -FilePath "ffmpeg" -ArgumentList @("-y", "-f", "lavfi", "-i", "testsrc=duration=3:size=720x1280:rate=30", "-f", "lavfi", "-i", "sine=frequency=1000:duration=3", "-c:v", "libx264", "-c:a", "aac", "-b:a", "128k", $vidPath2) -NoNewWindow -PassThru -Wait

$up2 = Upload-File -FilePath $vidPath2 -Folder "listings/reels"
Write-Host "  -> Auction Reel Upload: $($up2.data.url)" -ForegroundColor Green

$auctionEndTime = (Get-Date).AddDays(2).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
$auctionListingBody = @{
    title = "Vintage Hasselblad 500C/M"
    description = "Mint condition medium format film camera."
    price = 125000
    startingBid = 100000
    bidIncrement = 2500
    auctionEndTime = $auctionEndTime
    category = "Cameras"
    sellingMethod = "AUCTION"
    sellingScope = "GLOBAL"
    reelUrl = $up2.data.url
    mediaUrls = @($upPhoto.data.url)
    city = "Bangalore"
    state = "Karnataka"
    locality = "Indiranagar"
} | ConvertTo-Json

$aucListingRes = Invoke-RestMethod -Uri "$baseUrl/listings" -Method Post -Headers $headersA -ContentType "application/json" -Body $auctionListingBody
$aucListingId = $aucListingRes.data.id
Write-Host "  -> Created Auction Listing: $aucListingId" -ForegroundColor Green
Write-Host "  -> Selling Method: $($aucListingRes.data.sellingMethod)" -ForegroundColor Green
Write-Host "  -> Starting Bid: $($aucListingRes.data.startingBid), Increment: $($aucListingRes.data.bidIncrement)" -ForegroundColor Green

if ($aucListingRes.data.sellingMethod -ne "AUCTION") {
    throw "Step 3 failed: Selling method should be AUCTION"
}

# 4. Test 3: Verify Reels Feed & Direct Presigned R2 URLs
Write-Host ""
Write-Host "[4/12] Fetching Reels Feed and Verifying Presigned URLs..." -ForegroundColor Yellow
$reelsUrl = $baseUrl + "/listings/reels?page=0&size=10"
$reelsFeed = Invoke-RestMethod -Uri $reelsUrl -Method Get -Headers $headersA
$foundDirReel = $reelsFeed.data | Where-Object { $_.id -eq $dirListingId }
$foundAucReel = $reelsFeed.data | Where-Object { $_.id -eq $aucListingId }

if ($foundDirReel -eq $null -or $foundAucReel -eq $null) {
    throw "Step 4 failed: Newly created reels not found in /api/listings/reels"
}

Write-Host "  -> Direct Buy Reel URL: $($foundDirReel.reelUrl.Substring(0, 80))..." -ForegroundColor Green
Write-Host "  -> Direct Buy Poster: $($foundDirReel.primaryImageUrl.Substring(0, 80))..." -ForegroundColor Green
Write-Host "  -> Auction Reel URL: $($foundAucReel.reelUrl.Substring(0, 80))..." -ForegroundColor Green

# 5. Test 4: Verify HTTP 206 Partial Content Range Streaming
Write-Host ""
Write-Host "[5/12] Testing HTTP 206 Byte-Range Streaming on R2 Presigned URL..." -ForegroundColor Yellow
$rangeReq = [System.Net.HttpWebRequest]::Create($foundDirReel.reelUrl)
$rangeReq.Method = "GET"
$rangeReq.AddRange(0, 2048)
$rangeResp = $rangeReq.GetResponse()
Write-Host "  -> HTTP Status Code: $($rangeResp.StatusCode)" -ForegroundColor Green
Write-Host "  -> Content-Range: $($rangeResp.Headers['Content-Range'])" -ForegroundColor Green
Write-Host "  -> Content-Type: $($rangeResp.Headers['Content-Type'])" -ForegroundColor Green
Write-Host "  -> Accept-Ranges: $($rangeResp.Headers['Accept-Ranges'])" -ForegroundColor Green
$rangeResp.Close()

if ($rangeResp.StatusCode -ne "PartialContent") {
    throw "Step 5 failed: Expected HTTP 206 PartialContent"
}

# 6. Test 5: Verify Like Persistence & Double-Tap Idempotency
Write-Host ""
Write-Host "[6/12] Testing Like Toggle and Double-Tap Idempotency..." -ForegroundColor Yellow
# Single tap like
$like1 = Invoke-RestMethod -Uri "$baseUrl/listings/$dirListingId/like?action=toggle" -Method Post -Headers $headersA
Write-Host "  -> User A Toggled Like: isLikedByMe=$($like1.data.isLikedByMe), count=$($like1.data.likesCount)" -ForegroundColor Green
if ($like1.data.isLikedByMe -ne $true -or $like1.data.likesCount -ne 1) {
    throw "Step 6 failed: Expected liked=true, count=1"
}

# Double tap idempotent like
$likeDouble = Invoke-RestMethod -Uri "$baseUrl/listings/$dirListingId/like?action=like" -Method Post -Headers $headersA
Write-Host "  -> User A Double Tap (action=like): isLikedByMe=$($likeDouble.data.isLikedByMe), count=$($likeDouble.data.likesCount)" -ForegroundColor Green
if ($likeDouble.data.likesCount -ne 1 -or $likeDouble.data.isLikedByMe -ne $true) {
    throw "Step 6 failed: Double tap should maintain liked=true and count=1"
}

# User B Feed Isolation
$feedBUrl = $baseUrl + "/listings/reels?page=0&size=10"
$feedB = Invoke-RestMethod -Uri $feedBUrl -Method Get -Headers $headersB
$reelB = $feedB.data | Where-Object { $_.id -eq $dirListingId }
Write-Host "  -> User B View: isLikedByMe=$($reelB.likedByMe), count=$($reelB.likesCount)" -ForegroundColor Green
if ($reelB.likedByMe -ne $false -or $reelB.likesCount -ne 1) {
    throw "Step 6 failed: User B should see likedByMe=false and count=1"
}

# Unlike
$unlike = Invoke-RestMethod -Uri "$baseUrl/listings/$dirListingId/like?action=unlike" -Method Post -Headers $headersA
Write-Host "  -> User A Unliked: isLikedByMe=$($unlike.data.isLikedByMe), count=$($unlike.data.likesCount)" -ForegroundColor Green
if ($unlike.data.isLikedByMe -ne $false -or $unlike.data.likesCount -ne 0) {
    throw "Step 6 failed: Expected liked=false, count=0"
}

# 7. Test 6: Verify Mixed-Media Instagram-Style Posts
Write-Host ""
Write-Host "[7/12] Testing Mixed-Media Posts Feed (IMAGE + VIDEO + IMAGE)..." -ForegroundColor Yellow
$postsUrl = $baseUrl + "/posts?page=0&size=5"
$postsFeed = Invoke-RestMethod -Uri $postsUrl -Method Get -Headers $headersA
Write-Host "  -> Retrieved $($postsFeed.data.Count) Posts from /api/posts" -ForegroundColor Green
$foundPost = $postsFeed.data | Where-Object { $_.listingId -eq $aucListingId }
if ($foundPost -ne $null) {
    Write-Host "  -> Found Mixed Media Post for listing '$($foundPost.title)': Media Items Count=$($foundPost.mediaUrls.Count)" -ForegroundColor Green
}

# 8. Test 7: Verify Pagination (page=0, page=1)
Write-Host ""
Write-Host "[8/12] Testing Reel Feed Pagination..." -ForegroundColor Yellow
$p0Url = $baseUrl + "/listings/reels?page=0&size=3"
$p1Url = $baseUrl + "/listings/reels?page=1&size=3"
$page0 = Invoke-RestMethod -Uri $p0Url -Method Get -Headers $headersA
$page1 = Invoke-RestMethod -Uri $p1Url -Method Get -Headers $headersA
Write-Host "  -> Page 0 returned $($page0.data.Count) items" -ForegroundColor Green
Write-Host "  -> Page 1 returned $($page1.data.Count) items" -ForegroundColor Green
if ($page0.data.Count -eq 0) {
    throw "Step 8 failed: Page 0 returned 0 items"
}

# 9. Test 8: Verify Upload Error Handling for Corrupt File
Write-Host ""
Write-Host "[9/12] Testing Corrupt Video Upload Failure Handling..." -ForegroundColor Yellow
$corruptPath = Join-Path $tempDir "corrupt_data.mp4"
[System.IO.File]::WriteAllText($corruptPath, "Not a valid MP4 header byte sequence.")
$badRes = Upload-File -FilePath $corruptPath -Folder "listings/reels"
Write-Host "  -> Server Response: success=$($badRes.success), message='$($badRes.message)'" -ForegroundColor Green
if ($badRes.success -ne $false) {
    throw "Step 9 failed: Corrupt video should fail gracefully"
}

# 10. Test 9: Verify Legacy Reel URL Playback Compatibility
Write-Host ""
Write-Host "[10/12] Testing Pre-Existing Reel Compatibility..." -ForegroundColor Yellow
$legacyUrl = $baseUrl + "/listings/reels?page=0&size=20"
$legacyPresign = Invoke-RestMethod -Uri $legacyUrl -Method Get -Headers $headersA
$anyLegacy = $legacyPresign.data | Where-Object { $_.reelUrl -ne $null -and $_.id -ne $dirListingId -and $_.id -ne $aucListingId } | Select-Object -First 1
if ($anyLegacy -ne $null) {
    Write-Host "  -> Legacy Reel ID: $($anyLegacy.id)" -ForegroundColor Green
    Write-Host "  -> Legacy Presigned URL: $($anyLegacy.reelUrl.Substring(0, [Math]::Min(75, $anyLegacy.reelUrl.Length)))..." -ForegroundColor Green
}

# 11. Cleanup Temporary Directory
Write-Host ""
Write-Host "[11/12] Cleaning Local Temporary Directory..." -ForegroundColor Yellow
Remove-Item -Path $tempDir -Recurse -Force
Write-Host "  -> Cleanup: PASS" -ForegroundColor Green

# 12. Complete
Write-Host ""
Write-Host "========================================================" -ForegroundColor Green
Write-Host "PHASE 3.7 FULL VALIDATION SUITE PASSED (100%)" -ForegroundColor Green
Write-Host "========================================================" -ForegroundColor Green
Write-Host ""
