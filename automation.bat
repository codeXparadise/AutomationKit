@echo off
setlocal EnableDelayedExpansion
title AutomationKit Master Control
cd /d "%~dp0"

:: -------------------------------------------------------------
:: AutomationKit Unified CLI & Management Tool
:: Single control script for stack orchestration, DNS, and portal
:: -------------------------------------------------------------

set "ACTION=%~1"

if "%ACTION%"=="" goto :MENU
if /i "%ACTION%"=="start" goto :START
if /i "%ACTION%"=="up" goto :START
if /i "%ACTION%"=="stop" goto :STOP
if /i "%ACTION%"=="down" goto :STOP
if /i "%ACTION%"=="restart" goto :RESTART
if /i "%ACTION%"=="open" goto :OPEN_HUB
if /i "%ACTION%"=="hub" goto :OPEN_HUB
if /i "%ACTION%"=="docs" goto :OPEN_DOCS
if /i "%ACTION%"=="hosts" goto :SETUP_HOSTS
if /i "%ACTION%"=="setup-hosts" goto :SETUP_HOSTS
if /i "%ACTION%"=="status" goto :STATUS
if /i "%ACTION%"=="ps" goto :STATUS
if /i "%ACTION%"=="logs" goto :LOGS
if /i "%ACTION%"=="pull" goto :PULL
if /i "%ACTION%"=="update" goto :UPDATE
if /i "%ACTION%"=="reset-n8n" goto :RESET_N8N
if /i "%ACTION%"=="help" goto :HELP
if /i "%ACTION%"=="--help" goto :HELP
if /i "%ACTION%"=="-h" goto :HELP

echo [Error] Unknown command: %ACTION%
echo Run 'automation.bat help' for available commands.
exit /b 1

:MENU
cls
echo ====================================================================
echo   ⚡ AutomationKit — Unified Control Center (v1.0.0 Stable)
echo ====================================================================
echo.
echo   [1] Start Stack               - Pull images and start all 24+ containers
echo   [2] Stop Stack                - Gracefully shut down all containers
echo   [3] Restart Stack             - Restart the entire stack
echo   [4] Open Dashboard            - Launch Master Hub (http://localhost)
echo   [5] Open API ^& Docs           - Launch Knowledge Portal (http://localhost/docs.html)
echo   [6] Setup Local Domains       - Configure .local hosts in Windows
echo   [7] Container Status          - View live health ^& container state
echo   [8] Pull ^& Update Images      - Download latest container image layers
echo   [9] View Live Logs            - Stream Docker container logs
echo   [10] Reset n8n Password       - Reset owner account credentials
echo   [0] Exit
echo.
echo ====================================================================
set /p "CHOICE=Select an option [0-10]: "

if "%CHOICE%"=="1" goto :START
if "%CHOICE%"=="2" goto :STOP
if "%CHOICE%"=="3" goto :RESTART
if "%CHOICE%"=="4" goto :OPEN_HUB
if "%CHOICE%"=="5" goto :OPEN_DOCS
if "%CHOICE%"=="6" goto :SETUP_HOSTS
if "%CHOICE%"=="7" goto :STATUS
if "%CHOICE%"=="8" goto :PULL
if "%CHOICE%"=="9" goto :LOGS
if "%CHOICE%"=="10" goto :RESET_N8N
if "%CHOICE%"=="0" exit /b 0

echo Invalid selection.
timeout /t 2 >nul
goto :MENU

:START
echo.
echo [1/3] Pulling updated container images...
docker compose pull
echo.
echo [2/3] Building local task-runners...
docker compose build task-runners
echo.
echo [3/3] Starting AutomationKit stack in background...
docker compose up -d --remove-orphans
echo.
echo ====================================================================
echo  ✅ AutomationKit Stack is up and running!
echo  👉 Web Dashboard: http://localhost (or http://hub.local)
echo  👉 API ^& Docs Hub: http://localhost/docs.html
echo ====================================================================
docker compose ps
echo.
if "%ACTION%"=="" (
  echo Press any key to return to menu...
  pause >nul
  goto :MENU
)
exit /b 0

:STOP
echo.
echo Stopping AutomationKit stack...
docker compose down
echo.
echo [OK] All services stopped safely. Persistent data remains intact in .\data.
echo.
if "%ACTION%"=="" (
  echo Press any key to return to menu...
  pause >nul
  goto :MENU
)
exit /b 0

:RESTART
echo.
echo Restarting AutomationKit stack...
docker compose restart
echo.
echo [OK] Stack restarted.
docker compose ps
echo.
if "%ACTION%"=="" (
  echo Press any key to return to menu...
  pause >nul
  goto :MENU
)
exit /b 0

:OPEN_HUB
echo Opening Master Dashboard in browser...
start http://localhost
if "%ACTION%"=="" goto :MENU
exit /b 0

:OPEN_DOCS
echo Opening Knowledge & API Docs in browser...
start http://localhost/docs.html
if "%ACTION%"=="" goto :MENU
exit /b 0

:SETUP_HOSTS
echo.
echo Setting up local .local domain mappings...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\add-local-domains.ps1"
echo.
if "%ACTION%"=="" (
  echo Press any key to return to menu...
  pause >nul
  goto :MENU
)
exit /b 0

:STATUS
echo.
echo Current Container Status:
echo --------------------------------------------------------------------
docker compose ps
echo.
if "%ACTION%"=="" (
  echo Press any key to return to menu...
  pause >nul
  goto :MENU
)
exit /b 0

:PULL
echo.
echo Pulling latest images for all services...
docker compose pull
echo.
echo [OK] Images up to date.
if "%ACTION%"=="" (
  echo Press any key to return to menu...
  pause >nul
  goto :MENU
)
exit /b 0

:UPDATE
goto :START

:LOGS
echo.
set /p "SRV=Enter service name to stream logs (leave empty for all): "
if "%SRV%"=="" (
  docker compose logs -f --tail=100
) else (
  docker compose logs -f --tail=100 %SRV%
)
if "%ACTION%"=="" goto :MENU
exit /b 0

:RESET_N8N
echo.
echo Resetting n8n owner credentials...
docker exec -it n8n n8n user-management:reset
echo.
if "%ACTION%"=="" (
  echo Press any key to return to menu...
  pause >nul
  goto :MENU
)
exit /b 0

:HELP
echo AutomationKit Unified CLI Management Script
echo Usage: automation.bat [command]
echo.
echo Commands:
echo   start / up       Pull latest images and start all services
echo   stop / down      Stop all running containers
echo   restart          Restart all stack services
echo   open / hub       Launch Master Hub portal in browser (http://localhost)
echo   docs             Launch API ^& Knowledge Docs in browser (http://localhost/docs.html)
echo   hosts            Configure .local domains in Windows hosts file
echo   status / ps      Show Docker container status table
echo   logs [service]   Follow container logs (tail 100)
echo   pull             Pull latest Docker images
echo   reset-n8n        Reset n8n owner password
echo.
echo Running without arguments opens the interactive menu.
exit /b 0
