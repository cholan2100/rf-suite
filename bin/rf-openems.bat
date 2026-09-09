@echo off
setlocal
cd /d "%~dp0\.."

echo [RF Suite] Launching AppCSXCAD (openEMS 3D Viewer)...
docker compose up -d
docker compose exec -d rf-suite AppCSXCAD
start "" "http://localhost:6081/vnc.html"
