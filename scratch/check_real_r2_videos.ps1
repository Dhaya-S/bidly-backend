$res = Invoke-RestMethod -Uri 'http://localhost:8081/api/listings/reels?page=0&size=5' -Method Get
foreach ($r in $res.data) {
    Write-Host "Listing: $($r.title)"
    try {
        $req = [System.Net.HttpWebRequest]::Create($r.reelUrl)
        $req.Method = "GET"
        $req.AddRange(0, 1024)
        $resp = $req.GetResponse()
        Write-Host "  -> HTTP Status: $($resp.StatusCode)"
        Write-Host "  -> Content-Range: $($resp.Headers['Content-Range'])"
        Write-Host "  -> Content-Type: $($resp.Headers['Content-Type'])"
        Write-Host "  -> Content-Length: $($resp.Headers['Content-Length']) bytes"
        Write-Host "  -> Accept-Ranges: $($resp.Headers['Accept-Ranges'])"
        $resp.Close()
    } catch {
        Write-Host "  -> Error: $_"
    }
}
