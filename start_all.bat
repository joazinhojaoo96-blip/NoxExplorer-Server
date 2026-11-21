@echo off
title NoxExplorer - Launch All
cd /d C:\Users\Nexo_\Documents\NoxExplorer

echo [nox] ============================================
echo [nox]   NoxExplorer - AI Cheat Engine
echo [nox] ============================================
echo [nox] Starting all components...
echo.

echo [1/3] Launching LLaMA server (MiMo-V2.6)...
start "LLaMA Server" cmd /c start_llama.bat

echo [nox] Waiting 15s for llama to load model...
timeout /t 15 /nobreak >nul

echo [2/3] Launching Cloudflare tunnel...
start "CF Tunnel" cmd /c start_tunnel.bat

echo [nox] Waiting 10s for tunnel URL...
timeout /t 10 /nobreak >nul

echo [3/3] All components launched.
echo [nox] Check endpoint.txt for the tunnel URL.
echo [nox] Load nox_explorer.lua in your executor.
echo.
pause
