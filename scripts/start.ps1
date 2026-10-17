# Auto-update and Start Automation Stack with Persistent Data Preserved
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptDir

Set-Location $projectRoot

Write-Host "=====================================================" -ForegroundColor Cyan
Write-Host " 🚀 Starting Automation Stack (Auto-Update Enabled)" -ForegroundColor Cyan
Write-Host " 📁 Persistent Data: $projectRoot\data" -ForegroundColor Green
Write-Host "=====================================================" -ForegroundColor Cyan

Write-Host "`n[1/3] Checking and pulling latest Docker images..." -ForegroundColor Yellow
docker compose pull

Write-Host "`n[2/3] Building task-runners with latest base dependencies..." -ForegroundColor Yellow
docker compose build task-runners

Write-Host "`n[3/3] Starting updated containers (Persistent data preserved)..." -ForegroundColor Green
docker compose up -d --remove-orphans

Write-Host "`n✅ All services are up-to-date and running! Persistent data is intact." -ForegroundColor Green
docker compose ps
