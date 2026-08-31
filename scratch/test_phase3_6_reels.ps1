# scratch/test_phase3_6_reels.ps1
$ErrorActionPreference = "Stop"

$baseUrl = "http://localhost:8081/api"

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.6 VERIFICATION TEST SUITE" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

# 1. Authenticate User A and User B
Write-Host "[1/7] Authenticating User A (9840011111) and User B (9840022222)..." -ForegroundColor Yellow
$userAMobile = "9840011111"
$userBMobile = "9840022222"

$otpARes = Invoke-RestMethod -Uri "$baseUrl/auth/send-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userAMobile; name = "Priya Raman" } | ConvertTo-Json)
$authARes = Invoke-RestMethod -Uri "$baseUrl/auth/verify-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userAMobile; otp = "123456"; requestId = $otpARes.data.requestId; name = "Priya Raman" } | ConvertTo-Json)
$tokenA = $authARes.data.token
$userIdA = $authARes.data.user.id
Write-Host "  -> User A ID: $userIdA ('$($authARes.data.user.name)')" -ForegroundColor Green

$otpBRes = Invoke-RestMethod -Uri "$baseUrl/auth/send-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userBMobile; name = "Karthik Raja" } | ConvertTo-Json)
$authBRes = Invoke-RestMethod -Uri "$baseUrl/auth/verify-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userBMobile; otp = "123456"; requestId = $otpBRes.data.requestId; name = "Karthik Raja" } | ConvertTo-Json)
$tokenB = $authBRes.data.token
$userIdB = $authBRes.data.user.id
Write-Host "  -> User B ID: $userIdB ('$($authBRes.data.user.name)')" -ForegroundColor Green

$headersA = @{ Authorization = "Bearer $tokenA" }
$headersB = @{ Authorization = "Bearer $tokenB" }

# 2. User A creates a multi-media listing with reel video
Write-Host "`n[2/7] User A creates a Multi-Media Reel Listing..." -ForegroundColor Yellow
$createListingBody = @{
    title = "Phase 3.6 4K Camera Drone Reel"
    description = "4K HDR Drone with dual battery pack and cinematic video."
    price = 62000
    category = "Electronics"
    sellingMethod = "DIRECT_BUY"
    sellingScope = "GLOBAL"
    reelUrl = "listings/reels/phase3_6_drone_reel.mp4"
    mediaUrls = @(
        "listings/test-drone-photo1.jpg",
        "listings/test-drone-photo2.jpg",
        "listings/reels/phase3_6_drone_reel.mp4"
    )
    city = "Chennai"
    state = "Tamil Nadu"
    locality = "Besant Nagar"
} | ConvertTo-Json

$listingRes = Invoke-RestMethod -Uri "$baseUrl/listings" -Method Post -Headers $headersA -ContentType "application/json" -Body $createListingBody
$listingId = $listingRes.data.id
Write-Host "  -> Created Listing ID: $listingId ('$($listingRes.data.title)')" -ForegroundColor Green
Write-Host "  -> Initial state: likesCount=$($listingRes.data.likesCount), isLikedByMe=$($listingRes.data.isLikedByMe)" -ForegroundColor Green

# 3. User A likes Reel (Single Tap)
Write-Host "`n[3/7] User A likes Reel (Single Tap Toggle)..." -ForegroundColor Yellow
$likeRes = Invoke-RestMethod -Uri "$baseUrl/listings/$listingId/like" -Method Post -Headers $headersA
Write-Host "  -> Like Response: likesCount=$($likeRes.data.likesCount), isLikedByMe=$($likeRes.data.isLikedByMe)" -ForegroundColor Green
if ($likeRes.data.likesCount -ne 1 -or $likeRes.data.isLikedByMe -ne $true) {
    throw "Step 3 failed: Expected likesCount=1 and isLikedByMe=true"
}

# 4. User A double taps (Action = 'like') — Must be idempotent!
Write-Host "`n[4/7] Testing Double-Tap Idempotency (action=like on already-liked reel)..." -ForegroundColor Yellow
$doubleTapRes = Invoke-RestMethod -Uri "$baseUrl/listings/$listingId/like?action=like" -Method Post -Headers $headersA
Write-Host "  -> Double-Tap Response: likesCount=$($doubleTapRes.data.likesCount), isLikedByMe=$($doubleTapRes.data.isLikedByMe)" -ForegroundColor Green
if ($doubleTapRes.data.likesCount -ne 1 -or $doubleTapRes.data.isLikedByMe -ne $true) {
    throw "Step 4 failed: Double-tap caused unexpected unlike or double increment!"
}

# 5. User B fetches Reels feed — Must see isLikedByMe = false and likesCount = 1
Write-Host "`n[5/7] Verifying User B Reels feed isolation..." -ForegroundColor Yellow
$reelsB = Invoke-RestMethod -Uri "$baseUrl/listings/reels?page=0&size=10" -Method Get -Headers $headersB
$reelB = $reelsB.data | Where-Object { $_.id -eq $listingId }
Write-Host "  -> User B sees: isLikedByMe=$($reelB.isLikedByMe), likesCount=$($reelB.likesCount)" -ForegroundColor Green
if ($reelB.isLikedByMe -ne $false -or $reelB.likesCount -ne 1) {
    throw "Step 5 failed: User B saw incorrect like state or count!"
}

# 6. User A unlikes (Action = 'unlike')
Write-Host "`n[6/7] User A unlikes Reel (action=unlike)..." -ForegroundColor Yellow
$unlikeRes = Invoke-RestMethod -Uri "$baseUrl/listings/$listingId/like?action=unlike" -Method Post -Headers $headersA
Write-Host "  -> Unlike Response: likesCount=$($unlikeRes.data.likesCount), isLikedByMe=$($unlikeRes.data.isLikedByMe)" -ForegroundColor Green
if ($unlikeRes.data.likesCount -ne 0 -or $unlikeRes.data.isLikedByMe -ne $false) {
    throw "Step 6 failed: Expected likesCount=0 and isLikedByMe=false after unlike"
}

# 7. User A refreshes feed — Must see isLikedByMe = false and likesCount = 0
Write-Host "`n[7/7] User A refreshes Reels feed after unlike..." -ForegroundColor Yellow
$reelsA = Invoke-RestMethod -Uri "$baseUrl/listings/reels?page=0&size=10" -Method Get -Headers $headersA
$reelA = $reelsA.data | Where-Object { $_.id -eq $listingId }
Write-Host "  -> User A refreshed feed: isLikedByMe=$($reelA.isLikedByMe), likesCount=$($reelA.likesCount)" -ForegroundColor Green
if ($reelA.isLikedByMe -ne $false -or $reelA.likesCount -ne 0) {
    throw "Step 7 failed: Reels feed failed to reflect persistent unliked state!"
}

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "ALL PHASE 3.6 VERIFICATIONS PASSED SUCCESSFULLY (100%)" -ForegroundColor Green
Write-Host "========================================================`n" -ForegroundColor Green
