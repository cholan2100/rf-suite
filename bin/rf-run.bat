@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0\.."

rem 1. Check for AWS Mode via environment variable or .env file
set "AWS_MODE=0"
if /i "%RF_BACKEND%"=="aws" set "AWS_MODE=1"
if not "%AWS_INSTANCE_ID%"=="" set "AWS_MODE=1"

if "%AWS_MODE%"=="0" (
    if exist "..\.env" (
        for /f "tokens=1,2 delims==" %%a in ('findstr /i "^RF_BACKEND=aws ^AWS_INSTANCE_ID=" "..\.env" 2^>nul') do (
            set "AWS_MODE=1"
        )
    )
    if exist ".env" (
        for /f "tokens=1,2 delims==" %%a in ('findstr /i "^RF_BACKEND=aws ^AWS_INSTANCE_ID=" ".env" 2^>nul') do (
            set "AWS_MODE=1"
        )
    )
)

rem 2. If AWS mode, delegate to AWS remote execution runner
if "%AWS_MODE%"=="1" (
    echo [RF Suite] AWS Backend Active. Dispatching command to AWS host...
    cd /d "%~dp0\..\.."
    python -c "exit(0)" >nul 2>nul
    if !errorlevel! equ 0 (
        python -m agent.aws.rf_remote_client run %*
        exit /b !errorlevel!
    )
    py -3 -c "exit(0)" >nul 2>nul
    if !errorlevel! equ 0 (
        py -3 -m agent.aws.rf_remote_client run %*
        exit /b !errorlevel!
    )
    rem Fallback to WSL python3 if Windows Python is not on PATH
    for /f "delims=" %%i in ('wsl -d Debian wslpath "%~dp0..\.."') do set "WSL_ROOT=%%i"
    wsl -d Debian bash -c "cd !WSL_ROOT! && python3 -m agent.aws.rf_remote_client run %*"
    exit /b !errorlevel!
)

rem 3. Local Docker / WSL Execution Mode
echo [RF Suite] Running command inside local container: %*

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
