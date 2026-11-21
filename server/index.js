// NoxExplorer Gateway Server
// language: JavaScript (Node.js), file: server/index.js
// Receives class scan from Lua, forwards to local llama-server via cloudflared tunnel

'use strict';

const express = require('express');
const cors    = require('cors');
const fetch   = require('node-fetch');
const fs      = require('fs');
const path    = require('path');

const app  = express();
const PORT = process.env.PORT || 3000;

// llama-server endpoint — read from endpoint.txt in repo root or env
let LLAMA_URL = process.env.LLAMA_URL || '';

function load_endpoint() {
  try {
    const ep_file = path.join(__dirname, '..', 'endpoint.txt');
    const raw = fs.readFileSync(ep_file, 'utf8').trim();
    if (raw && raw !== 'https://placeholder.trycloudflare.com') {
      LLAMA_URL = raw;
      console.log('[nox] llama endpoint:', LLAMA_URL);
    }
  } catch (_) {}
}

load_endpoint();
// refresh endpoint every 60s (tunnel URL can change on restart)
setInterval(load_endpoint, 60_000);

app.use(cors());
app.use(express.json({ limit: '2mb' }));

// POST /analyze — receives { classes: [...], game: "..." }
// returns { code: "..lua code.." }
app.post('/analyze', async (req, res) => {
  const { classes, game } = req.body;
  if (!classes || !Array.isArray(classes)) {
    return res.status(400).json({ error: 'classes array required' });
  }

  if (!LLAMA_URL) {
    return res.status(503).json({ error: 'llama endpoint not configured' });
  }

  const class_summary = classes.slice(0, 80).map(c =>
    `${c.name}${c.methods ? ': ' + c.methods.slice(0,8).join(', ') : ''}`
  ).join('\n');

  const prompt = `You are a Lua game cheat developer. The following classes were found in the game "${game || 'unknown'}".
Analyze them and generate a complete, working Lua cheat script using the most useful classes.
Focus on: ESP (entity positions), aimbot hooks, speed/teleport, god mode, item collection.
Only output valid Lua code with comments. No explanations outside comments.

CLASSES FOUND:
${class_summary}

Generate the cheat script:`;

  try {
    const llm_res = await fetch(`${LLAMA_URL}/v1/chat/completions`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: 'local',
        messages: [{ role: 'user', content: prompt }],
        max_tokens: 2048,
        temperature: 0.3,
        stream: false
      }),
      timeout: 120_000
    });

    if (!llm_res.ok) throw new Error(`llama HTTP ${llm_res.status}`);
    const data  = await llm_res.json();
    const code  = data.choices?.[0]?.message?.content || '';
    return res.json({ code, classes_analyzed: classes.length });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// GET /health — simple probe
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', llama: LLAMA_URL || 'not set' });
});

// GET /endpoint — returns current llama URL (for Lua polling)
app.get('/endpoint', (_req, res) => {
  res.json({ url: LLAMA_URL });
});

app.listen(PORT, () => {
  console.log(`[nox] gateway running on :${PORT}`);
});
