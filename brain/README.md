# Nox Brain — Oracle Always Free

Cérebro da Nox: MiMo-V2.6-Q4_K_M rodando 24/7 num VM ARM grátis. Sem sono, sem conta no HF, sem cartão cobrado.

## Por que Oracle
- **Always Free de verdade**: 2 OCPU / 12GB RAM — o modelo Q4 (5.84GB) cabe folgado.
- IP público direto — o Railway conversa sem tunnel.
- Não dorme depois de 48h (diferente do HF).

## Passo a passo (uma vez só)

1. **Conta**: <https://cloud.oracle.com/free> — cartão só pra validar, nunca cobra.
2. **Criar instância** (Compute → Create Instance):
   - Image: **Ubuntu 22.04** (ou 24.04)
   - Shape: **VM.Standard.A1.Flex** → **2 OCPU, 16 GB? não — 12 GB** (máximo free)
   - Em **"Paste cloud-init script"**: cole o conteúdo inteiro de `brain/cloud-init.sh`
   - Boot volume: 50 GB (default serve)
3. **Abrir a porta**: após criar, em Networking → Virtual Cloud Network → Security Rules → **Ingress Rules** → Add:
   - Source CIDR: `0.0.0.0/0`, Destination Port: `8080`, TCP
4. **Esperar ~10 min** (download do modelo + binário). Teste:
   ```
   curl http://<IP_DA_INSTANCIA>:8080/health
   ```
   `200` ou `401` = cérebro vivo.
5. **Railway** (dashboard → Settings → Variables):
   ```
   NOX_BRAIN_URL = http://<IP_DA_INSTANCIA>:8080
   NOX_BRAIN_KEY = nox-brain-4080
   ```
   Deploy novo → `GET /brain-health` deve virar `"status":"up"` e o pill da UI vira "cérebro ligado".
6. **GitHub** (Settings → Secrets and variables → Actions):
   - `NOX_BRAIN_URL` / `NOX_BRAIN_KEY` — iguais do Railway
   - `ORACLE_HOST` — IP da instância
   - `ORACLE_SSH_KEY` — chave privada SSH (a que criou na Oracle)
   O workflow `brain-watch` passa a vigiar de 5 em 5 minutos e reinicia o serviço se morrer.

## Bugs (keep-alive) do projeto
| Bug | O que faz |
|---|---|
| `railway-keepalive.yml` | ping a cada 3 min no gateway |
| `fullstack.yml` | ping a cada 5 min + self-trigger |
| `brain-watch.yml` | vigia o cérebro a cada 5 min, reinicia via SSH se cair |

## Comandos úteis (SSH)
```
sudo systemctl status nox-brain
sudo journalctl -u nox-brain -f
tail -f /var/log/nox-brain-server.log
sudo systemctl restart nox-brain
```

## Trocar de quantização
Edite `brain/cloud-init.sh`, troque a URL do modelo (ex: `IQ4_XS` = 5.23GB, mais rápido; `Q6_K` = 7.79GB, mais fiel), apague `/opt/nox/model.gguf` e reabra a instância.
