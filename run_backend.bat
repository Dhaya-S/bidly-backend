@echo off
setlocal enabledelayedexpansion

:: Load .env variables
if exist .env (
    for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
        set "line=%%A"
        if not "!line:~0,1!"=="#" (
            set "%%A=%%B"
        )
    )
)

:: Reverse ADB port for USB device
adb reverse tcp:8081 tcp:8081 >nul 2>&1

:: Run JAR directly
echo Starting Bidly Backend on port 8081...
java -jar "build\libs\bidly-backend-0.0.1-SNAPSHOT.jar"
