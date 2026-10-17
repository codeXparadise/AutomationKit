@echo off
cd /d "%~dp0"

echo =====================================================
echo  Starting Automation Stack (Auto-Update Enabled)
echo  Persistent Data: .\data and .\shared
echo =====================================================

echo.
echo [1/3] Checking and pulling latest Docker images...
docker compose pull

echo.
echo [2/3] Building task-runners with latest base dependencies...
docker compose build task-runners

echo.
echo [3/3] Starting updated containers (Persistent data preserved)...
docker compose up -d --remove-orphans

echo.
echo =====================================================
echo  All services are up-to-date and running!
echo =====================================================
docker compose ps
pause
