# NoxExplorer - Quick Start Guide

## What You Get

✅ **24/7 Uptime** - Railway never sleeps due to keep-alive bug
✅ **AI-Powered** - MiMo-V2.6 generates cheat code from game classes
✅ **Cloud Native** - No local PC required after setup
✅ **Free Hosting** - $0/month (Railway + GitHub Pages)

## Setup in 5 Minutes

### 1. Deploy to Railway (2 minutes)

**Windows:**
```cmd
setup_railway.bat
```

**Mac/Linux:**
```bash
./setup_railway.sh
```

**Or manually:**
```bash
npm install -g @railway/cli
railway login
railway init
railway up
```

### 2. Get Your Railway URL (30 seconds)

- Check Railway dashboard
- Copy URL like: `https://noxexplorer-xxxx.up.railway.app`

### 3. Configure GitHub (1 minute)

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

### 4. Push and Wait (30 seconds)

```bash
git add .
git commit -m "deploy: railway setup"
git push
```

Wait 5 minutes. Check Railway dashboard - should show "Active".

### 5. Use in Game

```lua
-- In your Lua executor
loadstring(game:HttpGet("https://raw.githubusercontent.com/joazinhojaoo96-blip/NoxExplorer-Server/main/nox_explorer.lua"))()
```

## What Happens Next

1. **Every 3 minutes**: GitHub Actions pings Railway
2. **Railway stays awake**: Never sleeps due to constant activity
3. **Lua script scans game**: Finds all classes via reflection
4. **AI generates cheat**: MiMo-V2.6 creates working code
5. **Code executes**: Cheat runs in your game

## Monitoring

- **Status Page**: https://joazinhojaoo96-blip.github.io/NoxExplorer-Server/
- **Activity Log**: Check `activity.log` in repo
- **Railway Logs**: `railway logs`
- **GitHub Actions**: Actions tab in repo

## Troubleshooting

### "Service sleeping"
- Check `railway_url.txt` has correct URL
- Check GitHub secret `RAILWAY_URL` is set
- Check workflow permissions are "Read and write"

### "No endpoint found"
- Run `setup_railway.bat` again
- Check Railway deployment succeeded
- Verify URL in `railway_url.txt`

### "AI not responding"
- Check Railway logs: `railway logs`
- Verify `/health` endpoint: `curl https://your-url/health`
- Wait for AI model to load (may take 1-2 minutes)

## Files Explained

| File | Purpose |
|------|---------|
| `nox_explorer.lua` | Main script - runs in game |
| `railway-server.js` | API server with keep-alive |
| `railway.json` | Railway configuration |
| `railway_url.txt` | Your Railway URL |
| `setup_railway.bat` | Windows setup script |
| `.github/workflows/fullstack.yml` | Keep-alive workflows |
| `docs/index.html` | Status dashboard |

## Cost Breakdown

| Service | Cost |
|---------|------|
| Railway Free Tier | $5 credit/month (enough) |
| GitHub Actions | Free (public repo) |
| GitHub Pages | Free (public repo) |
| **Total** | **$0/month** |

## Next Steps

1. ✅ Deploy to Railway
2. ✅ Configure GitHub secrets
3. ✅ Enable GitHub Pages
4. ✅ Push to trigger keep-alive
5. ✅ Test in game
6. ✅ Monitor status page

## Need Help?

- Read `docs/DEPLOYMENT.md` for detailed guide
- Check `docs/RAILWAY_SETUP.md` for Railway specifics
- Check Railway logs: `railway logs`
- Check GitHub Actions: Actions tab

---

**Remember**: The keep-alive bug runs automatically. Once set up, Railway will NEVER sleep.
