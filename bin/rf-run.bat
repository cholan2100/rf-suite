@echo off
setlocal
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
    wsl -d Debian bash -c "cd /mnt/d/Workspace/rf/rf-suite && (docker compose exec rf-suite %* 2>/dev/null || docker compose run --rm rf-suite %*)"
)
