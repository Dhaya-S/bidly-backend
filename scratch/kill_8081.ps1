$pids = Get-NetTCPConnection -LocalPort 8081 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique
foreach ($p in $pids) {
    Write-Host "Killing process $p on port 8081"
    Stop-Process -Id $p -Force -ErrorAction SilentlyContinue
}
