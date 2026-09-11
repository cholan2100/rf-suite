@echo off
rem ==============================================================================
rem RF Suite SaaS Server Windows Launcher
rem Launches the FastAPI service inside the container toolchain
rem ==============================================================================
setlocal enabledelayedexpansion

cd /d "%~dp0\.."
echo [RF Suite SaaS] Starting FastAPI Design Engine via container on port 8000...
call bin\rf-run.bat uvicorn agent.saas.app:app --host 0.0.0.0 --port 8000
exit /b %errorlevel%
