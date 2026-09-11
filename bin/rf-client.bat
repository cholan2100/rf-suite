@echo off
rem ==============================================================================
rem RF SaaS Pure Native Windows Batch Launcher (Zero WSL required)
rem ==============================================================================
setlocal enabledelayedexpansion
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0rf-client.ps1" %*
exit /b %errorlevel%
