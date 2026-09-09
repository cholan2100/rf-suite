@echo off
setlocal
cd /d "%~dp0\.."

echo [RF Suite] Launching KiCad...
docker compose up -d
docker compose exec -d rf-suite kicad
start "" "http://localhost:6080/vnc.html"
