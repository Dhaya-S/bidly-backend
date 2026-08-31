$apiUrl = "http://localhost:8081/api/listings/reels?page=0&size=10"
Write-Host "Benchmarking GET $apiUrl..." -ForegroundColor Cyan

$times = @()
for ($i = 1; $i -le 5; $i++) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $res = Invoke-RestMethod -Uri $apiUrl -Method Get
    $sw.Stop()
    $ms = $sw.ElapsedMilliseconds
    $times += $ms
    $c = $res.data.Count
    Write-Host "  Run $i - $ms ms (Items: $c)" -ForegroundColor Yellow
}

$avg = ($times | Measure-Object -Average).Average
Write-Host "`nAverage Latency: $avg ms" -ForegroundColor Green
