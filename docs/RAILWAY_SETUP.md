# Railway Setup - Keep-Alive Bug

## How the Bug Works

Railway free tier pauses services after ~30 minutes of inactivity. The keep-alive bug works by:

1. **GitHub Actions cron job** runs every 3 minutes
2. Pings multiple Railway endpoints (`/health`, `/ping`, `/keepalive`, `/status`)
3. Sends POST requests to generate write activity
4. Self-triggers via empty commit (infinite loop)
5. Railway sees constant activity → never sleeps

## Setup Steps

### 1. Deploy to Railway

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Initialize in project root
railway init

# Link to project
railway link

# Deploy
railway up
```

Or use Railway dashboard:
1. Go to https://railway.app
2. Create new project
3. Connect GitHub repo `joazinhojaoo96-blip/NoxExplorer-Server`
4. Railway auto-detects `railway.json`

### 2. Get Railway URL

After deployment, Railway gives you a URL like:
```
https://your-app-name-xxxx.up.railway.app
```

### 3. Configure GitHub Secrets

Go to repo → Settings → Secrets and variables → Actions:

```
RAILWAY_URL = https://your-app-name-xxxx.up.railway.app
```

### 4. Update railway_url.txt

Replace the placeholder in `railway_url.txt` with your actual URL:
```
https://your-app-name-xxxx.up.railway.app
```

### 5. Enable GitHub Actions

The workflow `.github/workflows/railway-keepalive.yml` will:
- Run every 3 minutes (cron)
- Ping Railway endpoints
- Log activity
- Self-trigger for infinite loop

**Important**: Go to Settings → Actions → General → Workflow permissions → Select "Read and write permissions"

### 6. Verify

After 5 minutes, check:
- Railway dashboard shows "Active" status
- GitHub Actions runs are completing
- `activity.log` in repo is updating

## Endpoints

| Endpoint | Method | Purpose |
|----------|--------|---------|
| `/health` | GET | Health check |
| `/ping` | GET | Simple pong |
| `/keepalive` | POST | Write activity generator |
| `/status` | GET | Detailed status |
| `/activity` | GET | Recent activity log |
| `/analyze` | POST | AI analysis (main feature) |

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
gh run list --workflow=railway-keepalive.yml
```

## Troubleshooting

### Service still sleeping?
- Verify `RAILWAY_URL` secret is set correctly
- Check GitHub Actions runs are successful
- Ensure workflow permissions are "Read and write"

### Railway URL changed?
- Update `railway_url.txt` in repo
- Update `RAILWAY_URL` secret
- Next cron run will pick up new URL

### High CPU usage?
- Self-ping interval can be increased in `railway-server.js`
- Change `120_000` (2 min) to `300_000` (5 min)

## Cost

- **Railway Free Tier**: $5 credit/month (enough for this workload)
- **GitHub Actions**: Free for public repos
- **Total**: $0/month
