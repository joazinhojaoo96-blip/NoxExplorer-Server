# NoxExplorer - Railway Keep-Alive Bug

## The Bugzão (Big Bug) 🐛

Railway free tier sleeps after 30 minutes of inactivity. The keep-alive bug prevents this by:

1. **GitHub Actions cron** runs every 3 minutes
2. Pings Railway endpoints (`/health`, `/ping`, `/keepalive`, `/status`)
3. Sends POST requests (write activity - higher weight)
4. Self-triggers via empty commit (infinite loop)
5. Railway sees constant activity → **NEVER SLEEPS**

## What Was Built

### 1. Railway Server (`server/railway-server.js`)
- Express.js API gateway
- Self-pinging mechanism (every 2 minutes)
- Keep-alive endpoints
- Activity tracking

### 2. GitHub Actions Workflows
- `railway-keepalive.yml` - Pings Railway every 3 minutes
- `fullstack.yml` - Dual keep-alive (GitHub Actions + Railway)

### 3. GitHub Pages Dashboard (`docs/index.html`)
- Real-time status monitoring
- Activity log viewer
- Endpoint documentation

### 4. Setup Scripts
- `setup_railway.bat` - Windows
- `setup_railway.sh` - Linux/Mac

### 5. Documentation
- `QUICKSTART.md` - 5-minute setup guide
- `docs/DEPLOYMENT.md` - Detailed deployment guide
- `docs/RAILWAY_SETUP.md` - Railway-specific guide

## Next Steps (You Do This)

### Step 1: Deploy to Railway (2 minutes)

```cmd
setup_railway.bat
```

Or manually:
```bash
npm install -g @railway/cli
railway login
railway init
railway up
```

### Step 2: Get Railway URL

- Check Railway dashboard
- Copy URL like: `https://noxexplorer-xxxx.up.railway.app`

### Step 3: Configure GitHub (1 minute)

1. Edit `railway_url.txt`:
   ```
   https://noxexplorer-xxxx.up.railway.app
   ```

2. Set GitHub secret:
   - Repo → Settings → Secrets → Actions
   - Name: `RAILWAY_URL`
   - Value: `https://noxexplorer-xxxx.up.railway.app`

3. Enable permissions:
   - Settings → Actions → General
   - Select "Read and write permissions"

### Step 4: Enable GitHub Pages

1. Go to Settings → Pages
2. Source: "Deploy from a branch"
3. Branch: `main`
4. Folder: `/docs`
5. Click "Save"

Your site: `https://joazinhojaoo96-blip.github.io/NoxExplorer-Server/`

### Step 5: Push and Wait

```bash
git add .
git commit -m "deploy: railway setup"
git push
```

Wait 5 minutes. Check Railway dashboard - should show "Active".

## How It Works

```
Every 3 minutes:
┌─────────────────┐
│ GitHub Actions  │
│ (cron: */3)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐     ┌─────────────────┐
│ Ping Railway    │────▶│ Railway Stays   │
│ /health /ping   │     │ Awake (24/7)    │
│ /keepalive POST │     │                 │
└─────────────────┘     └─────────────────┘
         │
         ▼
┌─────────────────┐
│ Self-Trigger    │
│ (empty commit)  │
│ → Next run      │
└─────────────────┘
```

## Monitoring

- **Status Page**: https://joazinhojaoo96-blip.github.io/NoxExplorer-Server/
- **Activity Log**: Check `activity.log` in repo
- **Railway Logs**: `railway logs`
- **GitHub Actions**: Actions tab

## Cost

- **Railway**: $5 credit/month (enough)
- **GitHub Actions**: Free (public repo)
- **GitHub Pages**: Free (public repo)
- **Total**: $0/month

## Files

| File | Purpose |
|------|---------|
| `server/railway-server.js` | API server with keep-alive |
| `railway.json` | Railway configuration |
| `railway_url.txt` | Your Railway URL |
| `.github/workflows/fullstack.yml` | Dual keep-alive workflows |
| `docs/index.html` | Status dashboard |
| `setup_railway.bat` | Windows setup script |
| `QUICKSTART.md` | Quick start guide |

---

**The bug works automatically. Once set up, Railway will NEVER sleep.**
