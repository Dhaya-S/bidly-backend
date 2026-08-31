$r = Invoke-RestMethod -Uri "http://localhost:8081/api/listings/d2e6de93-bf3e-431e-9cff-8458ae845b29" -Method Get
Write-Host "ID: $($r.data.id)"
Write-Host "Title: $($r.data.title)"
Write-Host "Reel URL: $($r.data.reelUrl)"
Write-Host "Primary Image: $($r.data.primaryImageUrl)"

if ($r.data.reelUrl) {
    Write-Host "`nDownloading first 100KB of video to probe codec..."
    $webClient = New-Object System.Net.WebClient
    $tmp = "$env:TEMP\probe_failed_video.mp4"
    $webClient.DownloadFile($r.data.reelUrl, $tmp)
    & ffprobe -v error -show_entries stream=codec_name,profile,pix_fmt,width,height,color_space,color_transfer,color_primaries -of default=noprint_wrappers=1 $tmp
}
