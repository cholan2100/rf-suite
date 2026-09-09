@echo off
setlocal
cd /d "%~dp0\.."

echo ======================================================================
echo   Opening Interactive Bash Terminal in RF Suite
echo ======================================================================

where docker >nul 2>nul
if %errorlevel% equ 0 (
    docker compose exec -it rf-suite bash
    if errorlevel 1 (
        echo [RF Suite] Container not currently running. Starting interactive shell...
        docker compose run --rm -it rf-suite bash
    )
) else (
    rem Fallback to WSL docker if native docker is not in Windows PATH
    wsl -d Debian bash -c "cd /mnt/d/Workspace/rf/rf-suite && (docker compose exec -it rf-suite bash 2>/dev/null || docker compose run --rm -it rf-suite bash)"
)
