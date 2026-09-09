@echo off
setlocal
cd /d "%~dp0\.."

echo ======================================================================
echo   Starting RF Suite Container with Web Desktop
echo ======================================================================

where docker >nul 2>nul
if %errorlevel% equ 0 (
    docker compose up -d
) else (
    rem Fallback to WSL docker if native docker is not in Windows PATH
    setlocal enabledelayedexpansion
    for /f "delims=" %%i in ('wsl -d Debian wslpath "%~dp0.."') do set "WSL_DIR=%%i"
    wsl -d Debian bash -c "cd !WSL_DIR! 2>/dev/null || cd /mnt/d/Workspace/rf/rf-suite; docker compose up -d"
)

echo Waiting for noVNC web server to become ready...
timeout /t 3 /nobreak >nul

echo Opening browser at http://localhost:6080/vnc.html
start "" "http://localhost:6080/vnc.html"

echo.
echo Desktop is active! You can access:
echo   - Web Desktop: http://localhost:6080/vnc.html
echo   - Default Password: rfworkbench (if prompted)
echo.
pause
