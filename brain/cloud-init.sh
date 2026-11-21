#!/bin/bash
# Nox Brain — bootstrap Oracle Always Free (cola no campo cloud-init)
set -e
exec > >(tee -a /var/log/nox-brain-bootstrap.log) 2>&1
echo "[nox] bootstrap iniciado $(date -u)"

install -d -m 755 /opt/nox
cd /opt/nox

export DEBIAN_FRONTEND=noninteractive
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 5; done
apt-get update -y
apt-get install -y wget curl unzip ca-certificates git build-essential cmake libcurl4-openssl-dev

# 1) llama-server — binário ubuntu-arm64, fallback: compila do fonte
if [ ! -x /opt/nox/llama-server ]; then
  URL=$(curl -fsSL https://api.github.com/repos/ggml-org/llama.cpp/releases/latest \
    | grep -o 'https://[^"]*ubuntu-arm64[^"]*\.zip' | head -1 || true)
  if [ -n "$URL" ]; then
    echo "[nox] baixando binario: $URL"
    wget -q -O /opt/nox/llama.zip "$URL" || true
    unzip -o -q /opt/nox/llama.zip -d /opt/nox/pkg || true
    BIN=$(find /opt/nox/pkg -name llama-server -type f 2>/dev/null | head -1 || true)
    if [ -n "$BIN" ]; then
      cp "$BIN" /opt/nox/llama-server && chmod +x /opt/nox/llama-server
    fi
    rm -rf /opt/nox/pkg /opt/nox/llama.zip
  fi
fi
if [ ! -x /opt/nox/llama-server ]; then
  echo "[nox] compilando llama.cpp do fonte (~10 min)"
  git clone --depth 1 https://github.com/ggml-org/llama.cpp.git /opt/nox/src
  cmake -S /opt/nox/src -B /opt/nox/src/build -DGGML_NATIVE=ON -DLLAMA_CURL=ON
  cmake --build /opt/nox/src/build --config Release -j"$(nproc)" --target llama-server
  cp /opt/nox/src/build/bin/llama-server /opt/nox/llama-server
  rm -rf /opt/nox/src
fi
/opt/nox/llama-server --version || true

# 2) cérebro MiMo Q4_K_M (5.84GB) — wget -c retoma se rebootar no meio
if [ ! -s /opt/nox/model.gguf ]; then
  echo "[nox] baixando MiMo-V2.6 Q4_K_M..."
  wget -c -O /opt/nox/model.gguf \
    "https://huggingface.co/bartowski/MiMo-V2.6-Distill-Qwen-9B-GGUF/resolve/main/MiMo-V2.6-Distill-Qwen-9B-Q4_K_M.gguf"
fi
ls -lh /opt/nox/model.gguf

# 3) serviço — morre e volta sozinho (bug de vida)
cat > /etc/systemd/system/nox-brain.service <<'UNIT'
[Unit]
Description=Nox Brain (llama-server MiMo-V2.6)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/nox
ExecStart=/opt/nox/llama-server -m /opt/nox/model.gguf --host 0.0.0.0 --port 8080 -c 4096 -n 1024 --api-key nox-brain-4080
Restart=always
RestartSec=8
StandardOutput=append:/var/log/nox-brain-server.log
StandardError=append:/var/log/nox-brain-server.log

[Install]
WantedBy=multi-user.target
UNIT

systemctl daemon-reload
systemctl enable --now nox-brain
echo "[nox] bootstrap completo $(date -u) — teste: curl http://<IP>:8080/health"
