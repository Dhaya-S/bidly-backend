$envFile = Join-Path $PSScriptRoot ".env"
$jvmArgs = @()
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $val = $matches[2].Trim()
            [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
            $jvmArgs += "-D$key=$val"
        }
    }
}

# Free port 8081 if occupied
$portOccupied = Get-NetTCPConnection -LocalPort 8081 -ErrorAction SilentlyContinue | Select-Object -First 1
if ($portOccupied) {
    Stop-Process -Id $portOccupied.OwningProcess -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# Configure ADB reverse
$adbCmd = Get-Command adb -ErrorAction SilentlyContinue
$adbPath = $null
if ($adbCmd) { $adbPath = $adbCmd.Source }
elseif (Test-Path "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe") {
    $adbPath = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
}
if ($adbPath) {
    & $adbPath reverse tcp:8081 tcp:8081
}

$jarPath = Join-Path $PSScriptRoot "build\libs\bidly-backend-0.0.1-SNAPSHOT.jar"
$allArgs = $jvmArgs + @("-jar", "`"$jarPath`"")

Start-Process "javaw" -ArgumentList $allArgs -WorkingDirectory $PSScriptRoot
Write-Host "Started Bidly backend via javaw daemon."
