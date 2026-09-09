@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0\.."

echo [RF Suite] Running command inside container: %*

where docker >nul 2>nul
if %errorlevel% equ 0 (
    docker compose exec rf-suite %*
    if errorlevel 1 (
        echo [RF Suite] Container not currently running in background. Running via ephemeral container...
        docker compose run --rm rf-suite %*
    )
) else (
    rem Fallback to WSL docker if native docker is not in Windows PATH
    for /f "delims=" %%i in ('wsl -d Debian wslpath "%~dp0.."') do set "WSL_DIR=%%i"
    wsl -d Debian bash "!WSL_DIR!/bin/rf-run" %*
)
