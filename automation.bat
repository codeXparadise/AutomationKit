@echo off
setlocal
title AutomationKit — Unified Control Center
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0automation.ps1" %*
