@echo off
setlocal
cd /d "%~dp0\.."

echo [RF Suite] Launching FreeCAD...
docker compose up -d
docker compose exec -d rf-suite freecad
start "" "http://localhost:6081/vnc.html"
