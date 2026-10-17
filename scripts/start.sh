#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo "====================================================="
echo " 🚀 Starting Automation Stack (Auto-Update Enabled)"
echo " 📁 Persistent Data: $PROJECT_ROOT/data"
echo "====================================================="

echo ""
echo "[1/3] Checking and pulling latest Docker images..."
docker compose pull

echo ""
echo "[2/3] Building task-runners with latest base dependencies..."
docker compose build task-runners

echo ""
echo "[3/3] Starting updated containers (Persistent data preserved)..."
docker compose up -d --remove-orphans

echo ""
echo "✅ All services are up-to-date and running! Persistent data is intact."
docker compose ps
