@echo off
title NoxExplorer - LLaMA Server
cd /d C:\Users\Nexo_\Documents\NoxExplorer

echo [nox] Starting llama-server (MiMo-V2.6, CPU, port 8080)...
echo [nox] Context: 4096 tokens, threads: 8
echo [nox] Endpoint: http://localhost:8080

llama\llama-server.exe ^
  -m "MiMo-V2.6-Distill-Qwen-9B-IQ2_M.gguf" ^
  --mmproj "MiMo-V2.6-Distill-Qwen-9B-IQ2_M.mmproj.gguf" ^
  --port 8080 ^
  --host 0.0.0.0 ^
  -c 4096 ^
  -t 8 ^
  -n 2048 ^
  --no-mmap ^
  -v

pause
