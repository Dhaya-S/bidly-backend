$res = Invoke-RestMethod -Uri 'http://localhost:8081/api/listings/reels?page=0&size=1' -Method Get
$reelUrl = $res.data[0].reelUrl
Write-Host "Reel URL: $reelUrl"
$head = Invoke-WebRequest -Uri $reelUrl -Method Head
Write-Host "Status Code: $($head.StatusCode)"
Write-Host "Content-Length: $($head.Headers['Content-Length']) bytes ($([Math]::Round([double]$head.Headers['Content-Length'] / 1MB, 2)) MB)"
Write-Host "Content-Type: $($head.Headers['Content-Type'])"
Write-Host "Accept-Ranges: $($head.Headers['Accept-Ranges'])"
