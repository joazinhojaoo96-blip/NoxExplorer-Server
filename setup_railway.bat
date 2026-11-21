@echo off
REM NoxExplorer Railway Setup Script (Windows)
REM Deploys to Railway and configures keep-alive bug

echo ===========================================
echo  NoxExplorer Railway Setup
echo ===========================================

REM Check if Railway CLI is installed
where railway >nul 2>nul
if %errorlevel% neq 0 (
    echo [1/6] Installing Railway CLI...
    call npm install -g @railway/cli
) else (
    echo [1/6] Railway CLI already installed
)

REM Check if logged in
echo [2/6] Checking Railway login...
call railway whoami >nul 2>nul
if %errorlevel% neq 0 (
    echo Please login to Railway:
    call railway login
)

REM Initialize Railway project
echo [3/6] Initializing Railway project...
if not exist ".railway\project.json" (
    call railway init --name noxexplorer
) else (
    echo Railway project already initialized
)

REM Link to project
echo [4/6] Linking to Railway project...
call railway link

REM Deploy
echo [5/6] Deploying to Railway...
call railway up

REM Get the deployed URL
echo [6/6] Getting deployed URL...
for /f "tokens=*" %%i in ('call railway status --json 2^>nul ^| findstr /C:"domain"') do set RAILWAY_LINE=%%i

echo Railway URL detection:
echo %RAILWAY_LINE%

echo.
echo ===========================================
echo  Setup Complete!
echo ===========================================
echo.
echo Next steps:
echo 1. Check Railway dashboard for your app URL
echo 2. Update railway_url.txt with the URL
echo 3. Set GitHub secret RAILWAY_URL
echo 4. Enable GitHub Actions (Settings - Actions - Workflow permissions)
echo 5. Select 'Read and write permissions'
echo 6. Wait 5 minutes for first keep-alive ping
echo.
echo Your site: https://joazinhojaoo96-blip.github.io/NoxExplorer-Server/
echo.
echo The keep-alive bug will now run every 3 minutes via GitHub Actions
echo Railway will NEVER sleep due to constant activity
echo.
pause
