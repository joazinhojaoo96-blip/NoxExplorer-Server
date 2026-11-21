# NoxExplorer - AI Cheat Engine

AI-powered game class scanner and cheat generator. Scans all game classes via Lua reflection, sends them to MiMo-V2.6 AI, and executes the generated cheat code.

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Lua Script    │────▶│  Railway API    │────▶│   GitHub Actions│
│  (Game Client)  │     │   (Gateway)     │     │  (Keep-Alive)   │
└─────────────────┘     └─────────────────┘     └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  Class Scanner  │     │  AI Analysis    │     │  Constant Ping  │
│   (Reflection)  │     │   (MiMo-V2.6)   │     │   (Every 3min)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

## Components

### 1. Lua Script (`nox_explorer.lua`)
- Scans game classes via Roblox reflection
- Extracts methods and properties from metatables
- Sends class data to Railway API
- Executes generated cheat code

### 2. Railway Server (`server/railway-server.js`)
- Express.js API gateway
- Self-pinging mechanism (every 2 minutes)
- Keep-alive endpoints
- AI analysis stub (ready for MiMo integration)

### 3. GitHub Actions Keep-Alive (`.github/workflows/railway-keepalive.yml`)
- Runs every 3 minutes
- Pings Railway endpoints
- Sends POST requests for write activity
- Self-triggers via empty commit (infinite loop)
- **Prevents Railway free tier from sleeping**

### 4. GitHub Pages (`docs/index.html`)
- Status dashboard
- Real-time activity monitoring
- Endpoint documentation

## Quick Start

### Deploy to Railway

```bash
# Windows
setup_railway.bat

# Linux/Mac
chmod +x setup_railway.sh
./setup_railway.sh
```

### Manual Setup

1. **Deploy to Railway**
   ```bash
   npm install -g @railway/cli
   railway login
   railway init
   railway up
   ```

2. **Get Railway URL**
   - Check Railway dashboard
   - Copy the URL (e.g., `https://your-app.up.railway.app`)

3. **Configure GitHub**
   - Update `railway_url.txt` with your URL
   - Set GitHub secret `RAILWAY_URL`
   - Enable Actions: Settings → Actions → Workflow permissions → "Read and write"

4. **Enable Keep-Alive**
   - Push any commit to trigger workflow
   - Wait 5 minutes
   - Check Railway dashboard - should show "Active"

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/ping` | GET | Simple pong response |
| `/keepalive` | POST | Write activity generator |
| `/status` | GET | Detailed status info |
| `/activity` | GET | Recent activity log |
| `/analyze` | POST | AI analysis (main feature) |

## The Keep-Alive Bug

Railway free tier pauses services after ~30 minutes of inactivity. The keep-alive bug works by:

1. **GitHub Actions cron** runs every 3 minutes
2. Pings multiple Railway endpoints
3. Sends POST requests (write activity)
4. Self-triggers via empty commit (infinite loop)
5. Railway sees constant activity → **never sleeps**

### Why It Works

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

### Check Activity
```bash
cat activity.log
```

### Check GitHub Actions
```bash
gh run list --workflow=railway-keepalive.yml
```

## File Structure

```
NoxExplorer-Server/
├── .github/
│   └── workflows/
│       ├── keepalive.yml          # GitHub Actions infinite loop
│       └── railway-keepalive.yml  # Railway keep-alive bug
├── docs/
│   ├── index.html                 # GitHub Pages dashboard
│   └── RAILWAY_SETUP.md           # Detailed setup guide
├── server/
│   ├── index.js                   # Original gateway server
│   ├── railway-server.js          # Railway server with keep-alive
│   ├── package.json               # Original dependencies
│   └── package-railway.json       # Railway dependencies
├── nox_explorer.lua               # Main Lua script
├── railway.json                   # Railway configuration
├── railway_url.txt                # Current Railway URL
├── endpoint.txt                   # Legacy endpoint (Cloudflare)
├── setup_railway.bat              # Windows setup script
├── setup_railway.sh               # Linux/Mac setup script
├── activity.log                   # Activity tracking
└── README.md                      # This file
```

## Configuration

### GitHub Secrets

| Secret | Description |
|--------|-------------|
| `RAILWAY_URL` | Your Railway app URL |

### Environment Variables (Railway)

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | 3000 | Server port |

## Troubleshooting

### Service Still Sleeping?
- Verify `RAILWAY_URL` secret is set correctly
- Check GitHub Actions runs are successful
- Ensure workflow permissions are "Read and write"

### Railway URL Changed?
- Update `railway_url.txt`
- Update `RAILWAY_URL` secret
- Next cron run will pick up new URL

### High CPU Usage?
- Increase self-ping interval in `railway-server.js`
- Change `120_000` (2 min) to `300_000` (5 min)

## Cost

- **Railway Free Tier**: $5 credit/month (enough for this workload)
- **GitHub Actions**: Free for public repos
- **GitHub Pages**: Free for public repos
- **Total**: $0/month

## License

MIT License - see [LICENSE](LICENSE) file

## Credits

- **AI Model**: MiMo-V2.6-Distill-Qwen-9B
- **Hosted by**: Railway.app
- **Keep-Alive**: GitHub Actions
- **Dashboard**: GitHub Pages
