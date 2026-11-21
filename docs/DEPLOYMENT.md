# NoxExplorer Deployment Guide

## Overview

NoxExplorer uses a dual keep-alive strategy to ensure 24/7 uptime:

1. **GitHub Actions Infinite Loop** - Keeps a runner slot alive for 6 hours
2. **Railway Keep-Alive Bug** - Pings Railway every 3 minutes to prevent sleep

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Repository                         │
├─────────────────────────────────────────────────────────────┤
│  nox_explorer.lua  │  server/  │  .github/workflows/        │
│  (Game Client)     │  (API)    │  (Keep-Alive)              │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Railway.app                               │
├─────────────────────────────────────────────────────────────┤
│  railway-server.js  │  Self-Ping  │  Keep-Alive Endpoints   │
│  (Express API)      │  (2 min)    │  /health /ping /keepalive│
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    GitHub Pages                              │
├─────────────────────────────────────────────────────────────┤
│  docs/index.html  │  Status Dashboard  │  Activity Monitor   │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Steps

### Step 1: Deploy to Railway

#### Option A: Using Setup Script (Recommended)

**Windows:**
```cmd
setup_railway.bat
```

**Linux/Mac:**
```bash
chmod +x setup_railway.sh
./setup_railway.sh
```

#### Option B: Manual Deployment

1. **Install Railway CLI**
   ```bash
   npm install -g @railway/cli
   ```

2. **Login to Railway**
   ```bash
   railway login
   ```

3. **Initialize Project**
   ```bash
   railway init --name noxexplorer
   ```

4. **Deploy**
   ```bash
   railway up
   ```

5. **Get Your URL**
   - Check Railway dashboard
   - Copy URL (e.g., `https://noxexplorer-xxxx.up.railway.app`)

### Step 2: Configure GitHub

1. **Update railway_url.txt**
   ```
   https://noxexplorer-xxxx.up.railway.app
   ```

2. **Set GitHub Secret**
   - Go to repo → Settings → Secrets and variables → Actions
   - Click "New repository secret"
   - Name: `RAILWAY_URL`
   - Value: `https://noxexplorer-xxxx.up.railway.app`

3. **Enable Workflow Permissions**
   - Go to Settings → Actions → General
   - Under "Workflow permissions"
   - Select "Read and write permissions"
   - Click "Save"

### Step 3: Enable GitHub Pages

1. Go to Settings → Pages
2. Source: "Deploy from a branch"
3. Branch: `main`
4. Folder: `/docs`
5. Click "Save"

Your site will be at: `https://joazinhojaoo96-blip.github.io/NoxExplorer-Server/`

### Step 4: Trigger Keep-Alive

1. Push any commit to `main` branch
2. Wait 5 minutes
3. Check Railway dashboard - should show "Active"
4. Check GitHub Actions - should show running workflows

## The Keep-Alive Bug Explained

### Problem
Railway free tier pauses services after ~30 minutes of inactivity.

### Solution
GitHub Actions runs every 3 minutes and pings Railway endpoints.

### How It Works

1. **Cron Schedule**: `*/3 * * * *` (every 3 minutes)
2. **Multiple Endpoints**: `/health`, `/ping`, `/keepalive`, `/status`
3. **Write Activity**: POST requests to `/keepalive`
4. **Self-Trigger**: Empty commit at end of workflow
5. **Infinite Loop**: Each workflow triggers the next

### Why Railway Stays Awake

- Railway tracks HTTP requests as "activity"
- GET requests = read activity
- POST requests = write activity (higher weight)
- Multiple endpoints = more activity signals
- GitHub Actions runs = consistent, reliable pings
- Self-trigger = infinite loop, no manual intervention

## Monitoring

### Check Railway Status
```bash
railway status
railway logs
```

### Check Activity Log
```bash
cat activity.log
```

### Check GitHub Actions
```bash
gh run list --workflow=fullstack.yml
```

### Check GitHub Pages
Visit: `https://joazinhojaoo96-blip.github.io/NoxExplorer-Server/`

## Troubleshooting

### Service Still Sleeping?

1. **Check Railway URL**
   ```bash
   cat railway_url.txt
   ```
   - Should show your actual Railway URL
   - Not `https://your-railway-app.up.railway.app`

2. **Check GitHub Secret**
   - Go to Settings → Secrets → Actions
   - `RAILWAY_URL` should be set

3. **Check Workflow Permissions**
   - Settings → Actions → General
   - Should be "Read and write permissions"

4. **Check GitHub Actions Runs**
   - Go to Actions tab
   - Should see `fullstack.yml` runs every 3 minutes

### Railway URL Changed?

1. Update `railway_url.txt` with new URL
2. Update GitHub secret `RAILWAY_URL`
3. Next cron run will pick up new URL

### High CPU Usage?

In `server/railway-server.js`, find:
```javascript
}, 120_000); // Every 2 minutes
```

Change to:
```javascript
}, 300_000); // Every 5 minutes
```

## Cost

- **Railway Free Tier**: $5 credit/month
- **GitHub Actions**: Free for public repos
- **GitHub Pages**: Free for public repos
- **Total**: $0/month

## Security Notes

- GitHub secret `RAILWAY_URL` is private
- Railway URL is public but rate-limited
- No sensitive data in repository
- Activity log only contains timestamps and URLs

## Support

- Railway Docs: https://docs.railway.app
- GitHub Actions Docs: https://docs.github.com/en/actions
- GitHub Pages Docs: https://docs.github.com/en/pages
