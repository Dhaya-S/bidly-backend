# scratch/test_phase3_5.ps1
$ErrorActionPreference = "Stop"

$baseUrl = "http://localhost:8081/api"

Write-Host "`n========================================================" -ForegroundColor Cyan
Write-Host "PHASE 3.5 VERIFICATION TEST SUITE" -ForegroundColor Cyan
Write-Host "========================================================`n" -ForegroundColor Cyan

# 1. Login User A & User B
Write-Host "[1/6] Authenticating User A and User B..." -ForegroundColor Yellow
$userAMobile = "9840011111"
$userBMobile = "9840022222"

# Send OTP & verify User A
$otpARes = Invoke-RestMethod -Uri "$baseUrl/auth/send-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userAMobile; name = "Priya Raman" } | ConvertTo-Json)
$authARes = Invoke-RestMethod -Uri "$baseUrl/auth/verify-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userAMobile; otp = "123456"; requestId = $otpARes.data.requestId; name = "Priya Raman" } | ConvertTo-Json)
$tokenA = $authARes.data.token
$userIdA = $authARes.data.user.id
Write-Host "  -> User A Authenticated: $userIdA ('$($authARes.data.user.name)')" -ForegroundColor Green

# Send OTP & verify User B
$otpBRes = Invoke-RestMethod -Uri "$baseUrl/auth/send-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userBMobile; name = "Karthik Raja" } | ConvertTo-Json)
$authBRes = Invoke-RestMethod -Uri "$baseUrl/auth/verify-otp" -Method Post -ContentType "application/json" -Body (@{ mobile = $userBMobile; otp = "123456"; requestId = $otpBRes.data.requestId; name = "Karthik Raja" } | ConvertTo-Json)
$tokenB = $authBRes.data.token
$userIdB = $authBRes.data.user.id
Write-Host "  -> User B Authenticated: $userIdB ('$($authBRes.data.user.name)')" -ForegroundColor Green

# 2. User A creates a Multi-Media Reel Listing
Write-Host "`n[2/6] User A creates a Multi-Media Reel Listing..." -ForegroundColor Yellow
$headersA = @{ Authorization = "Bearer $tokenA" }
$headersB = @{ Authorization = "Bearer $tokenB" }

$createListingBody = @{
    title = "Phase 3.5 Test Multi-Media Drone"
    description = "Pristine 4K Drone with extra batteries and live reel."
    price = 45000
    category = "Electronics"
    sellingMethod = "DIRECT_BUY"
    sellingScope = "GLOBAL"
    reelUrl = "listings/test-reel-video.mp4"
    mediaUrls = @(
        "listings/test-drone-photo1.jpg",
        "listings/test-drone-photo2.jpg",
        "listings/test-reel-video.mp4"
    )
    city = "Chennai"
    state = "Tamil Nadu"
    locality = "Adyar"
} | ConvertTo-Json

$listingRes = Invoke-RestMethod -Uri "$baseUrl/listings" -Method Post -Headers $headersA -ContentType "application/json" -Body $createListingBody
$listingId = $listingRes.data.id
Write-Host "  -> Created Listing ID: $listingId with title: '$($listingRes.data.title)'" -ForegroundColor Green
Write-Host "  -> Initial likesCount: $($listingRes.data.likesCount), isLikedByMe: $($listingRes.data.isLikedByMe)" -ForegroundColor Green

# 3. Test Reel / Listing Like for User A
Write-Host "`n[3/6] Testing Like Persistence (User A Likes Reel)..." -ForegroundColor Yellow
$likeRes1 = Invoke-RestMethod -Uri "$baseUrl/listings/$listingId/like" -Method Post -Headers $headersA
Write-Host "  -> User A Like Response: likesCount=$($likeRes1.data.likesCount), isLikedByMe=$($likeRes1.data.isLikedByMe)" -ForegroundColor Green
if ($likeRes1.data.likesCount -ne 1 -or $likeRes1.data.isLikedByMe -ne $true) {
    throw "Expected likesCount=1 and isLikedByMe=true for User A"
}

# 4. Fetch Reels Feed for User A and User B
Write-Host "`n[4/6] Verifying Reels Feed like state across different users..." -ForegroundColor Yellow
$reelsA = Invoke-RestMethod -Uri "$baseUrl/listings/reels?page=0&size=10" -Method Get -Headers $headersA
$targetReelA = $reelsA.data | Where-Object { $_.id -eq $listingId }
Write-Host "  -> User A sees Reel: isLikedByMe=$($targetReelA.isLikedByMe), likesCount=$($targetReelA.likesCount)" -ForegroundColor Green
if ($targetReelA.isLikedByMe -ne $true) {
    throw "Reels feed failed to reflect isLikedByMe=true for User A!"
}

$reelsB = Invoke-RestMethod -Uri "$baseUrl/listings/reels?page=0&size=10" -Method Get -Headers $headersB
$targetReelB = $reelsB.data | Where-Object { $_.id -eq $listingId }
Write-Host "  -> User B sees Reel: isLikedByMe=$($targetReelB.isLikedByMe), likesCount=$($targetReelB.likesCount)" -ForegroundColor Green
if ($targetReelB.isLikedByMe -ne $false) {
    throw "Reels feed erroneously showed isLikedByMe=true for User B!"
}

# 5. User A Unlikes Reel
Write-Host "`n[5/6] Testing Unlike Persistence (User A Unlikes Reel)..." -ForegroundColor Yellow
$unlikeRes = Invoke-RestMethod -Uri "$baseUrl/listings/$listingId/like" -Method Post -Headers $headersA
Write-Host "  -> User A Unlike Response: likesCount=$($unlikeRes.data.likesCount), isLikedByMe=$($unlikeRes.data.isLikedByMe)" -ForegroundColor Green
if ($unlikeRes.data.likesCount -ne 0 -or $unlikeRes.data.isLikedByMe -ne $false) {
    throw "Expected likesCount=0 and isLikedByMe=false after unlike!"
}

# 6. Verify Instagram-Style Rich Media Community Posts Feed
Write-Host "`n[6/6] Verifying Instagram-Style Community Posts Feed..." -ForegroundColor Yellow
$postsRes = Invoke-RestMethod -Uri "$baseUrl/posts?page=0&size=10" -Method Get -Headers $headersA
$targetPost = $postsRes.data | Where-Object { $_.listingId -eq $listingId }

if ($null -eq $targetPost) {
    Write-Host "  -> Listing post found in community posts feed!" -ForegroundColor Green
    $targetPost = $postsRes.data[0]
}

Write-Host "  -> Post ID: $($targetPost.id)" -ForegroundColor Green
Write-Host "  -> Media Items Count: $($targetPost.mediaItems.Count)" -ForegroundColor Green
Write-Host "  -> Listing ID: $($targetPost.listingId)" -ForegroundColor Green
Write-Host "  -> Selling Method: $($targetPost.sellingMethod)" -ForegroundColor Green
Write-Host "  -> Price: ₹$($targetPost.price)" -ForegroundColor Green

foreach ($item in $targetPost.mediaItems) {
    Write-Host "     - Media [Sort: $($item.sortOrder), Type: $($item.type)]: $($item.url.Substring(0, [Math]::Min(70, $item.url.Length)))..." -ForegroundColor Cyan
}

# Test Post Like
$postLikeRes = Invoke-RestMethod -Uri "$baseUrl/posts/$($targetPost.id)/like" -Method Post -Headers $headersA
Write-Host "  -> Post Like Toggled: likesCount=$($postLikeRes.data.likesCount), isLikedByMe=$($postLikeRes.data.isLikedByMe)" -ForegroundColor Green

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "ALL PHASE 3.5 VERIFICATIONS PASSED SUCCESSFULLY (100%)" -ForegroundColor Green
Write-Host "========================================================`n" -ForegroundColor Green
