@echo off
title NoxExplorer - Cloudflare Tunnel
cd /d C:\Users\Nexo_\Documents\NoxExplorer

echo [nox] Starting cloudflared quick tunnel -> localhost:8080
echo [nox] URL will be captured and pushed to endpoint.txt

REM Start cloudflared in background, pipe stderr (where URL appears) to temp file
start "" /B cloudflared.exe tunnel --url http://localhost:8080 --logfile tunnel.log 2>&1

echo [nox] Waiting for tunnel URL (up to 30s)...
set URL=
set /a tries=0

:wait_loop
timeout /t 2 /nobreak >nul
set /a tries+=1
if %tries% gtr 15 goto no_url

REM Extract the trycloudflare.com URL from log
for /f "tokens=*" %%L in ('findstr "trycloudflare.com" tunnel.log 2^>nul') do (
    for /f "tokens=4 delims= " %%U in ("%%L") do set URL=%%U
)
if "%URL%"=="" goto wait_loop

:got_url
echo [nox] Tunnel URL: %URL%
echo %URL%> endpoint.txt
echo [nox] Pushing endpoint.txt to GitHub...
git add endpoint.txt
git commit -m "endpoint: %URL%"
git push origin main
echo [nox] endpoint.txt published. Lua script will pick it up.
goto end

:no_url
echo [nox] Could not detect tunnel URL. Check tunnel.log
type tunnel.log

:end
echo.
echo [nox] Tunnel running. Keep this window open.
cmd /k
