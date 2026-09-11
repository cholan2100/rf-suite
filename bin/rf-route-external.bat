@echo off
rem ==============================================================================
rem RF SaaS External Router Windows Launcher
rem Routes external physical LAN IP (192.168.0.100:8000) to containerized SaaS
rem ==============================================================================
setlocal enabledelayedexpansion

set "LISTEN_IP=%~1"
if "%LISTEN_IP%"=="" set "LISTEN_IP=192.168.0.100"

set "LISTEN_PORT=%~2"
if "%LISTEN_PORT%"=="" set "LISTEN_PORT=8000"

rem Auto-detect WSL IP
set "BACKEND_IP="
for /f "tokens=1" %%i in ('wsl -d Debian hostname -I 2^>nul') do (
    if not defined BACKEND_IP set "BACKEND_IP=%%i"
)
if "%BACKEND_IP%"=="" set "BACKEND_IP=127.0.0.1"

rem Ensure standalone binary exists
if not exist "%~dp0rf-route-external.exe" (
    echo [RF SaaS Router] Compiling native proxy binary...
    C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /optimize /target:exe /out:"%~dp0rf-route-external.exe" "%~dp0rf-route-external.cs"
)

rem Keep WSL awake
start /b wsl -d Debian sleep infinity >nul 2>nul

echo [RF SaaS Router] Starting Native Router on %LISTEN_IP%:%LISTEN_PORT% -> %BACKEND_IP%:%LISTEN_PORT%...
"%~dp0rf-route-external.exe" "%LISTEN_IP%" %LISTEN_PORT% "%BACKEND_IP%" %LISTEN_PORT%
exit /b %errorlevel%
