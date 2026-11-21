# NoxExplorer

AI-powered game class scanner and cheat generator.
Uses MiMo-V2.6 (local GGUF) + Cloudflare tunnel + GitHub Actions keepalive.

## Stack
- **llama-server** — MiMo-V2.6-Distill-Qwen-9B runs locally, exposed via cloudflared
- **server/index.js** — Node.js gateway (runs in GitHub Actions, 24/7 via self-push loop)
- **nox_explorer.lua** — executor script: scans classes, calls AI, runs generated cheat

## Usage
1. Run `start_all.bat` on your PC
2. Wait for `endpoint.txt` to be pushed to this repo
3. Load `nox_explorer.lua` in your executor

## GitHub Actions
Workflow keeps itself alive via empty-commit self-push loop.
Set **Settings → Actions → Workflow permissions → Read and write** before first run.
