$res = Invoke-RestMethod -Uri 'http://localhost:8081/api/listings/reels?page=0&size=2' -Method Get
$res | ConvertTo-Json -Depth 5
