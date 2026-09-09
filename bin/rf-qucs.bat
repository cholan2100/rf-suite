@echo off
setlocal
cd /d "%~dp0\.."

echo [RF Suite] Launching Qucs-S...
docker compose up -d
docker compose exec -d rf-suite qucs-s
start "" "http://localhost:6081/vnc.html"
