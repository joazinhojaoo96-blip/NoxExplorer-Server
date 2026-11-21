#!/bin/bash
# NoxExplorer Railway Setup Script
# Deploys to Railway and configures keep-alive bug

set -e

echo "==========================================="
echo " NoxExplorer Railway Setup"
echo "==========================================="

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "[1/6] Installing Railway CLI..."
    npm install -g @railway/cli
else
    echo "[1/6] Railway CLI already installed"
fi

# Check if logged in
echo "[2/6] Checking Railway login..."
if ! railway whoami &> /dev/null; then
    echo "Please login to Railway:"
    railway login
fi

# Initialize Railway project
echo "[3/6] Initializing Railway project..."
if [ ! -f ".railway/project.json" ]; then
    railway init --name noxexplorer
else
    echo "Railway project already initialized"
fi

# Link to project
echo "[4/6] Linking to Railway project..."
railway link

# Deploy
echo "[5/6] Deploying to Railway..."
railway up

# Get the deployed URL
echo "[6/6] Getting deployed URL..."
RAILWAY_URL=$(railway status --json | grep -o '"domain":[^,]*' | cut -d'"' -f4)

if [ -z "$RAILWAY_URL" ]; then
    echo "Warning: Could not auto-detect Railway URL"
    echo "Please check Railway dashboard for your app URL"
    echo "Then update:"
    echo "  1. railway_url.txt"
    echo "  2. GitHub Secret RAILWAY_URL"
else
    echo "Railway URL: $RAILWAY_URL"
    
    # Update railway_url.txt
    echo "$RAILWAY_URL" > railway_url.txt
    echo "Updated railway_url.txt"
    
    # Update GitHub secret (requires gh CLI)
    if command -v gh &> /dev/null; then
        echo "Setting GitHub secret RAILWAY_URL..."
        echo "$RAILWAY_URL" | gh secret set RAILWAY_URL
    else
        echo "Warning: gh CLI not found"
        echo "Please manually set GitHub secret:"
        echo "  Repository → Settings → Secrets → Actions"
        echo "  Name: RAILWAY_URL"
        echo "  Value: $RAILWAY_URL"
    fi
fi

echo ""
echo "==========================================="
echo " Setup Complete!"
echo "==========================================="
echo ""
echo "Next steps:"
echo "1. Enable GitHub Actions (Settings → Actions → Workflow permissions)"
echo "2. Select 'Read and write permissions'"
echo "3. Wait 5 minutes for first keep-alive ping"
echo "4. Check Railway dashboard - should show 'Active'"
echo ""
echo "Your site: https://joazinhojaoo96-blip.github.io/NoxExplorer-Server/"
echo "API: $RAILWAY_URL"
echo ""
echo "The keep-alive bug will now run every 3 minutes via GitHub Actions"
echo "Railway will NEVER sleep due to constant activity"
