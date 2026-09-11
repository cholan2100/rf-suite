@echo off
rem ==============================================================================
rem RF SaaS External Router Windows Launcher
rem Routes external physical LAN IP (192.168.0.100:8000) to local container SaaS
rem ==============================================================================
setlocal enabledelayedexpansion

set "TARGET_IP=%~1"
if "%TARGET_IP%"=="" set "TARGET_IP=192.168.0.100"

set "TARGET_PORT=%~2"
if "%TARGET_PORT%"=="" set "TARGET_PORT=8000"

echo [RF SaaS Router] Starting External Network Router on %TARGET_IP%:%TARGET_PORT%...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0rf-route-external.ps1" -ListenIP "%TARGET_IP%" -ListenPort %TARGET_PORT% -TargetPort %TARGET_PORT%
exit /b %errorlevel%
