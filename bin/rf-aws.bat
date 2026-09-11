@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0\..\.."

rem Check if Windows native Python works (avoiding WindowsApps Microsoft Store stub)
python -c "exit(0)" >nul 2>nul
if %errorlevel% equ 0 (
    python -m agent.aws.rf_remote_client %*
    exit /b %errorlevel%
)

rem Check Python launcher py -3
py -3 -c "exit(0)" >nul 2>nul
if %errorlevel% equ 0 (
    py -3 -m agent.aws.rf_remote_client %*
    exit /b %errorlevel%
)

rem Fallback to WSL python3 if Windows Python is not functional
for /f "delims=" %%i in ('wsl -d Debian wslpath "%cd%"') do set "WSL_ROOT=%%i"
wsl -d Debian python3 "!WSL_ROOT!/agent/aws/rf_remote_client.py" %*
exit /b %errorlevel%
