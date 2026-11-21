// NoxExplorer Railway Server with Keep-Alive Bug
// language: JavaScript (Node.js), file: server/railway-server.js, runtime: node >=18 (global fetch)
// AI gateway: /analyze returns real Roblox Lua cheat code
// Provider chain: OpenAI-compatible (LLM_BASE_URL/LLM_API_KEY env) -> Pollinations (keyless) -> local template
// *watch the pollinations free limit: 1 reply / 45s / IP — template fallback absorbs the 402*

'use strict';

const express = require('express');
const cors    = require('cors');
const http    = require('http');
const path    = require('path');

const app  = express();
const PORT = process.env.PORT || 3000;
const START_TIME = Date.now();
const AI_TIMEOUT_MS = Number(process.env.AI_TIMEOUT_MS || 45000);

// Activity tracking
let requestCount = 0;
let lastActivity = Date.now();
const activityLog = [];

app.use(cors());
app.use(express.json({ limit: '2mb' }));

// Middleware to track activity
app.use((req, res, next) => {
  requestCount++;
  lastActivity = Date.now();
  activityLog.push({
    time: new Date().toISOString(),
    method: req.method,
    path: req.path,
    ip: req.ip
  });
  if (activityLog.length > 1000) activityLog.shift();
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    uptime: Math.floor((Date.now() - START_TIME) / 1000),
    requests: requestCount,
    lastActivity: new Date(lastActivity).toISOString()
  });
});

// Ping endpoint
app.get('/ping', (req, res) => {
  res.json({ pong: true, ts: Date.now() });
});

// Keep-alive endpoint (POST - write activity)
app.post('/keepalive', (req, res) => {
  const { source, ts } = req.body || {};
  res.json({
    status: 'kept-alive',
    source: source || 'unknown',
    received: ts || Date.now(),
    serverTime: Date.now()
  });
});

// Status endpoint
app.get('/status', async (req, res) => {
  res.json({
    name: 'NoxExplorer Gateway',
    version: '3.0.0',
    uptime: Math.floor((Date.now() - START_TIME) / 1000),
    requests: requestCount,
    lastActivity: new Date(lastActivity).toISOString(),
    brain: await brainSnapshot(),
    recentActivity: activityLog.slice(-10)
  });
});

// Activity log endpoint
app.get('/activity', (req, res) => {
  res.json({
    total: activityLog.length,
    entries: activityLog.slice(-50)
  });
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    service: 'NoxExplorer AI Gateway',
    version: '3.0.0',
    endpoints: ['/health', '/ping', '/keepalive', '/status', '/activity', '/analyze', '/chat', '/brain-health', '/nox.html'],
    chat: 'POST /chat {messages:[{role,content}], stream?:bool} -> SSE stream or {reply, provider}',
    site: 'GET /nox.html — chat da Nox',
    ai: {
      primary: process.env.LLM_BASE_URL ? 'openai-compatible (env)' : 'pollinations (keyless)',
      fallback: 'template (always available)'
    },
    note: 'This service stays awake via GitHub Actions keep-alive bug'
  });
});

// Nox chat UI served straight from the repo docs/
app.get('/nox', (req, res) => res.redirect('/nox.html'));
app.use(express.static(path.join(__dirname, '..', 'docs'), { index: false }));

// =========================================================
// PROMPT
// =========================================================
function buildPrompt(classes, gameName) {
  const lines = classes.slice(0, 140).map((c) => {
    const methods = Array.isArray(c.methods) && c.methods.length
      ? c.methods.slice(0, 14).join(', ')
      : 'n/a';
    return `- ${c.name} [${c.class}] methods: ${methods}`;
  });

  const sys = [
    'You are an expert Roblox exploit developer.',
    'Respond with ONLY raw Lua 5.1 code for a Roblox executor',
    '(Synapse X / KRNL / Fluxus / YUbx-x).',
    'No markdown fences, no commentary, no explanations.',
    'The code runs inside loadstring().',
    'Wrap risky calls in pcall.',
    'Only use services that appear in the provided class list.'
  ].join(' ');

  const user = [
    `Game: ${gameName || 'unknown'}`,
    `Detected classes (${classes.length}):`,
    ...lines,
    '',
    'Generate ONE complete multi-toggle cheat script.',
    'Bind every toggle to a key via UserInputService.InputBegan',
    'and ignore input when gameProcessedEvent is true:',
    '- ESP: Highlight instances on other players (key E)',
    '- Speed: Humanoid.WalkSpeed boost (key Q)',
    '- Jump: Humanoid.JumpPower boost, UseJumpPower=true (key J)',
    '- Fly: BodyVelocity + BodyGyro, WASD + Space/Ctrl relative to camera (key F)',
    '- Noclip: RunService.Stepped disables CanCollide on character parts (key N)',
    'Start with every feature OFF.',
    'Print a clear ON/OFF message for each toggle.',
    'Capture base WalkSpeed/JumpPower before modifying.',
    'Reply with code only.'
  ].join('\n');

  return { sys, user };
}

function extractCode(raw) {
  if (!raw || typeof raw !== 'string') return null;
  let s = raw.trim();

  const fence = s.match(/```(?:lua|luau)?\s*([\s\S]*?)```/i);
  if (fence) s = fence[1].trim();

  const firstLine = s.split('\n')[0] || '';
  if (/^(here|sure|certainly|of course|as an ai|i can|i will|sorry)/i.test(firstLine)
      && !/local\s|game\s*:/.test(s)) {
    return null;
  }

  const idx = s.search(/local\s+[\w_]+\s*=|game\s*:|getgenv\s*\(|loadstring\s*\(/);
  if (idx > 0) s = s.slice(idx);

  if (s.length < 60) return null;
  if (!/local\s|game\s*:|function\s/.test(s)) return null;
  return s;
}

// =========================================================
// AI PROVIDERS
// =========================================================
async function chatOpenAI(baseUrl, apiKey, model, sys, user) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), AI_TIMEOUT_MS);
  try {
    const r = await fetch(`${baseUrl.replace(/\/$/, '')}/chat/completions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: sys },
          { role: 'user', content: user }
        ],
        temperature: 0.4,
        max_tokens: 2500
      }),
      signal: ctrl.signal
    });
    if (!r.ok) throw new Error(`openai-compatible HTTP ${r.status}`);
    const j = await r.json();
    const content = j.choices && j.choices[0] && j.choices[0].message
      ? j.choices[0].message.content
      : null;
    if (Array.isArray(content)) {
      return content.map((p) => (typeof p === 'string' ? p : p.text || '')).join('');
    }
    return content;
  } finally {
    clearTimeout(timer);
  }
}

async function chatPollinations(sys, user) {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), AI_TIMEOUT_MS);
  try {
    const r = await fetch('https://text.pollinations.ai/openai', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: process.env.POLLI_MODEL || 'openai',
        messages: [
          { role: 'system', content: sys },
          { role: 'user', content: user }
        ],
        temperature: 0.4,
        max_tokens: 2500,
        referrer: 'NoxExplorer'
      }),
      signal: ctrl.signal
    });
    if (r.status === 402) throw new Error('pollinations: free limit (402)');
    if (!r.ok) throw new Error(`pollinations HTTP ${r.status}`);
    const text = (await r.text()).trim();
    if (text.startsWith('{')) {
      try {
        const j = JSON.parse(text);
        if (j.status === 402 || j.error) {
          throw new Error(`pollinations: ${j.error && j.error.code || 'error'}`);
        }
        const content = j.choices && j.choices[0] && j.choices[0].message
          ? j.choices[0].message.content
          : null;
        if (content) return content;
      } catch (e) {
        if (e.message.startsWith('pollinations:')) throw e;
      }
    }
    return text;
  } finally {
    clearTimeout(timer);
  }
}

// =========================================================
// TEMPLATE FALLBACK — always returns working cheat code
// =========================================================
function templateCheat(gameName) {
  return `-- NoxExplorer generated cheat (template engine)
-- Game: ${gameName || 'unknown'}
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local lp = Players.LocalPlayer

local state = { esp = false, speed = false, jump = false, fly = false, noclip = false }
local baseSpeed, baseJump = 16, 50
local flyBV, flyBG, flyConn, noclipConn = nil, nil, nil, nil

local function log(m) print("[nox-cheat] " .. tostring(m)) end
local function char() return lp and lp.Character end
local function hum()
  local c = char()
  return c and c:FindFirstChildOfClass("Humanoid")
end

local function applyESP(on)
  for _, plr in ipairs(Players:GetPlayers()) do
    local c = plr.Character
    if c and plr ~= lp then
      local h = c:FindFirstChild("NoxESP")
      if on then
        if not h then
          h = Instance.new("Highlight")
          h.Name = "NoxESP"
          h.FillColor = Color3.fromRGB(255, 0, 70)
          h.OutlineColor = Color3.fromRGB(255, 255, 255)
          h.FillTransparency = 0.6
          h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
          h.Parent = c
        end
        h.Enabled = true
      elseif h then
        h:Destroy()
      end
    end
  end
end

local function setNoclip(on)
  if on then
    noclipConn = RunService.Stepped:Connect(function()
      local c = char()
      if c then
        for _, p in ipairs(c:GetDescendants()) do
          if p:IsA("BasePart") then p.CanCollide = false end
        end
      end
    end)
  elseif noclipConn then
    noclipConn:Disconnect()
    noclipConn = nil
  end
end

local function setFly(on)
  local c = char()
  local h = hum()
  if on then
    local hrp = c and c:FindFirstChild("HumanoidRootPart")
    if not hrp or not h then return end
    h.PlatformStand = true
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1, 1, 1) * 1e5
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = hrp
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxForce = Vector3.new(1, 1, 1) * 1e5
    flyBG.P = 1e4
    flyBG.Parent = hrp
    flyConn = RunService.RenderStepped:Connect(function()
      if not (flyBV and flyBV.Parent) then return end
      local cam = workspace.CurrentCamera
      local dir = Vector3.zero
      if UIS:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
      if UIS:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
      if UIS:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
      if UIS:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
      if UIS:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
      if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
      flyBV.Velocity = dir.Magnitude > 0 and dir.Unit * 65 or Vector3.zero
      flyBG.CFrame = cam.CFrame
    end)
  else
    if flyConn then flyConn:Disconnect(); flyConn = nil end
    if flyBV then flyBV:Destroy(); flyBV = nil end
    if flyBG then flyBG:Destroy(); flyBG = nil end
    if h then h.PlatformStand = false end
  end
end

UIS.InputBegan:Connect(function(inp, gp)
  if gp then return end
  local kc = inp.KeyCode
  if kc == Enum.KeyCode.Q then
    local h = hum()
    if h then
      if not state.speed then baseSpeed = h.WalkSpeed end
      state.speed = not state.speed
      h.WalkSpeed = state.speed and baseSpeed + 45 or baseSpeed
      log("Speed " .. (state.speed and "ON" or "OFF"))
    end
  elseif kc == Enum.KeyCode.J then
    local h = hum()
    if h then
      if not state.jump then baseJump = h.JumpPower end
      state.jump = not state.jump
      h.UseJumpPower = true
      h.JumpPower = state.jump and baseJump + 50 or baseJump
      log("Jump " .. (state.jump and "ON" or "OFF"))
    end
  elseif kc == Enum.KeyCode.E then
    state.esp = not state.esp
    applyESP(state.esp)
    log("ESP " .. (state.esp and "ON" or "OFF"))
  elseif kc == Enum.KeyCode.F then
    state.fly = not state.fly
    setFly(state.fly)
    log("Fly " .. (state.fly and "ON" or "OFF"))
  elseif kc == Enum.KeyCode.N then
    state.noclip = not state.noclip
    setNoclip(state.noclip)
    log("Noclip " .. (state.noclip and "ON" or "OFF"))
  end
end)

Players.PlayerAdded:Connect(function(plr)
  plr.CharacterAdded:Connect(function()
    wait(1)
    if state.esp then applyESP(true) end
  end)
end)

lp.CharacterAdded:Connect(function()
  wait(1)
  if state.speed then local h = hum(); if h then h.WalkSpeed = baseSpeed + 45 end end
  if state.jump then local h = hum(); if h then h.UseJumpPower = true; h.JumpPower = baseJump + 50 end end
  if state.noclip then setNoclip(false); setNoclip(true) end
  if state.fly then setFly(false); setFly(true) end
end)

print("=========================================")
print(" NoxExplorer cheat loaded")
print(" Game: ${gameName || 'unknown'}")
print(" Q=Speed  J=Jump  E=ESP  F=Fly  N=Noclip")
print("=========================================")
`;
}

// =========================================================
// ANALYZE
// =========================================================
app.post('/analyze', async (req, res) => {
  const { classes, game } = req.body || {};
  if (!classes || !Array.isArray(classes) || classes.length === 0) {
    return res.status(400).json({ error: 'classes array required' });
  }

  const started = Date.now();
  try {
    const { sys, user } = buildPrompt(classes, game);
    const attempts = [];
    const force = process.env.NOX_PROVIDER || 'auto';
    let code = null;
    let provider = null;

    const chain = [];
    const envUrl = process.env.LLM_BASE_URL;
    const envKey = process.env.LLM_API_KEY;
    const envModel = process.env.LLM_MODEL || 'openai';
    if (envUrl && envKey) {
      chain.push({
        name: `openai:${envModel}`,
        fn: () => chatOpenAI(envUrl, envKey, envModel, sys, user)
      });
    }
    chain.push({ name: 'pollinations', fn: () => chatPollinations(sys, user) });

    if (force !== 'auto' && force !== 'template') {
      const filtered = chain.filter((p) => p.name.includes(force));
      chain.length = 0;
      chain.push(...filtered);
    }

    if (force !== 'template') {
      for (const p of chain) {
        try {
          const raw = await p.fn();
          const extracted = extractCode(raw);
          if (extracted) {
            code = extracted;
            provider = p.name;
            break;
          }
          attempts.push(`${p.name}: empty/invalid (${String(raw || '').slice(0, 80)})`);
        } catch (e) {
          attempts.push(`${p.name}: ${e.message}`);
        }
      }
    }

    if (!code) {
      code = templateCheat(game);
      provider = 'template-fallback';
    }

    const ms = Date.now() - started;
    console.log(
      `[analyze] provider=${provider} ms=${ms} classes=${classes.length}` +
      (attempts.length ? ` attempts=[${attempts.join(' | ')}]` : '')
    );

    res.json({
      code,
      provider,
      classes_analyzed: classes.length,
      game: game || 'unknown',
      ms,
      ...(attempts.length ? { attempts } : {})
    });
  } catch (e) {
    console.error('[analyze] fatal:', e.message);
    res.json({
      code: templateCheat(game),
      provider: 'template-fallback',
      classes_analyzed: classes.length,
      game: game || 'unknown',
      ms: Date.now() - started,
      error: e.message
    });
  }
});

// =========================================================
// NOX CHAT — streaming gateway: brain (llama.cpp) -> pollinations failover
// =========================================================
const NOX_SYSTEM = [
  'Você é Nox — a IA pessoal do seu criador. Nome: Nox.',
  'Idioma: português brasileiro por padrão; se o usuário escrever em outro idioma, responde nesse idioma.',
  'Personalidade: direta, afiada, sem enrolação. Gosta de construir coisas.',
  'Pode conversar, programar, pesquisar e brincar.',
  'Nunca diga que é um assistente genérico — você é Nox.',
  'Se perguntarem o modelo, diga que roda no cérebro MiMo.',
  'Respostas úteis e no tamanho certo: nada de repetir a pergunta nem parágrafos de introdução.'
].join(' ');

function sanitizeMessages(input) {
  if (!Array.isArray(input)) return null;
  const msgs = input
    .filter((m) => m && (m.role === 'user' || m.role === 'assistant') && typeof m.content === 'string')
    .slice(-30)
    .map((m) => ({ role: m.role, content: m.content.slice(0, 6000) }));
  return msgs.length ? msgs : null;
}

function brainReady() {
  return Boolean(process.env.NOX_BRAIN_URL && process.env.NOX_BRAIN_KEY);
}

async function callBrain(messages, stream) {
  const base = String(process.env.NOX_BRAIN_URL).replace(/\/+$/, '');
  const r = await fetch(base + '/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer ' + process.env.NOX_BRAIN_KEY
    },
    body: JSON.stringify({
      model: 'nox',
      messages: [{ role: 'system', content: NOX_SYSTEM }, ...messages],
      temperature: 0.7,
      max_tokens: 1200,
      stream: Boolean(stream)
    }),
    signal: AbortSignal.timeout(180_000)
  });
  if (!r.ok) throw new Error('brain HTTP ' + r.status);
  return r;
}

async function callPollinations(messages, stream) {
  const r = await fetch('https://text.pollinations.ai/openai', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: process.env.POLLI_MODEL || 'openai',
      messages: [{ role: 'system', content: NOX_SYSTEM }, ...messages],
      temperature: 0.7,
      max_tokens: 1200,
      stream: Boolean(stream),
      referrer: 'NoxExplorer'
    }),
    signal: AbortSignal.timeout(75_000)
  });
  if (r.status === 402) {
    const err = new Error('pollinations free limit');
    err.retryAfter = 45;
    throw err;
  }
  if (!r.ok) throw new Error('pollinations HTTP ' + r.status);
  return r;
}

let brainCache = { at: 0, value: null };
async function brainSnapshot() {
  if (Date.now() - brainCache.at < 60_000 && brainCache.value) return brainCache.value;
  let value;
  if (!brainReady()) {
    value = { configured: false, status: 'not-configured' };
  } else {
    try {
      const base = String(process.env.NOX_BRAIN_URL).replace(/\/+$/, '');
      const r = await fetch(base + '/health', {
        headers: { Authorization: 'Bearer ' + process.env.NOX_BRAIN_KEY },
        signal: AbortSignal.timeout(5000)
      });
      value = { configured: true, status: r.ok || r.status === 401 || r.status === 403 ? 'up' : 'down', http: r.status };
    } catch (e) {
      value = { configured: true, status: 'down', error: e.message };
    }
  }
  brainCache = { at: Date.now(), value };
  return value;
}

app.get('/brain-health', async (req, res) => {
  res.json(await brainSnapshot());
});

app.post('/chat', async (req, res) => {
  const messages = sanitizeMessages(req.body && req.body.messages);
  if (!messages) return res.status(400).json({ error: 'messages array required' });

  const wantStream = !(req.body && req.body.stream === false);
  const chain = [];
  if (brainReady()) chain.push({ name: 'brain', call: callBrain });
  chain.push({ name: 'pollinations', call: callPollinations });

  const attempts = [];
  let retryAfter = null;

  for (const p of chain) {
    let upstream;
    try {
      upstream = await p.call(messages, wantStream);
    } catch (e) {
      attempts.push(p.name + ': ' + e.message);
      if (e.retryAfter) retryAfter = e.retryAfter;
      console.log('[chat] ' + p.name + ' failed: ' + e.message);
      continue;
    }

    if (!wantStream) {
      let parsed = null;
      try { parsed = await upstream.json(); } catch (_) {}
      const reply = parsed && parsed.choices && parsed.choices[0] &&
        parsed.choices[0].message && parsed.choices[0].message.content;
      if (reply) {
        console.log('[chat] provider=' + p.name + ' chars=' + reply.length);
        return res.json({ reply, provider: p.name });
      }
      attempts.push(p.name + ': empty reply');
      continue;
    }

    const reader = upstream.body.getReader();
    let first;
    try {
      first = await reader.read();
    } catch (e) {
      attempts.push(p.name + ': stream start ' + e.message);
      continue;
    }
    if (first.done) {
      attempts.push(p.name + ': stream empty');
      continue;
    }

    res.status(200);
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.write('data: ' + JSON.stringify({ provider: p.name }) + '\n\n');
    res.write(Buffer.from(first.value));

    let died = false;
    try {
      for (;;) {
        const chunk = await reader.read();
        if (chunk.done) break;
        res.write(Buffer.from(chunk.value));
      }
    } catch (e) {
      died = true;
      console.log('[chat] stream died (' + p.name + '): ' + e.message);
    } finally {
      try { reader.cancel(); } catch (_) {}
    }
    if (!res.writableEnded) res.write('data: [DONE]\n\n');
    res.end();
    console.log('[chat] stream provider=' + p.name + (died ? ' (died mid-stream)' : ''));
    return;
  }

  const payload = { error: 'Nox está fora do ar agora. Tenta de novo em instantes.' };
  if (retryAfter) {
    payload.retryAfter = retryAfter;
    payload.error = 'Nox está no limite gratuito. Espera ' + retryAfter + 's e tenta de novo.';
  }
  console.log('[chat] all providers failed: ' + attempts.join(' | '));
  res.status(503).json(payload);
});

// Self-ping using built-in http (no external deps)
setInterval(() => {
  const opts = { hostname: '127.0.0.1', port: PORT, path: '/ping', method: 'GET', timeout: 5000 };
  const req = http.request(opts, (res) => {
    if (res.statusCode === 200) {
      console.log(`[self-ping] OK at ${new Date().toISOString()}`);
    }
  });
  req.on('error', () => {});
  req.on('timeout', () => { req.destroy(); });
  req.end();
}, 120_000);

app.listen(PORT, () => {
  console.log(`[nox] Railway server running on :${PORT}`);
  console.log(`[nox] Self-ping active every 2 minutes`);
  console.log(`[nox] AI chain: ${process.env.LLM_BASE_URL ? 'openai-env + ' : ''}pollinations -> template`);
});
