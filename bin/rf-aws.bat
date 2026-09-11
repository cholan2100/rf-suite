@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0\..\.."

where python >nul 2>nul
if %errorlevel% equ 0 (
    python -m agent.aws.rf_remote_client %*
    exit /b %errorlevel%
)

where py >nul 2>nul
if %errorlevel% equ 0 (
    py -3 -m agent.aws.rf_remote_client %*
    exit /b %errorlevel%
)

rem Fallback to WSL python3 if Windows Python is not in PATH
for /f "delims=" %%i in ('wsl -d Debian wslpath "%cd%"') do set "WSL_ROOT=%%i"
wsl -d Debian bash -c "cd !WSL_ROOT! && python3 -m agent.aws.rf_remote_client %*"
exit /b %errorlevel%
