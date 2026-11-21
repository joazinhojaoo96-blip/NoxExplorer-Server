// NoxExplorer Railway Server with Keep-Alive Bug
// language: JavaScript (Node.js), file: server/railway-server.js
// Self-pinging mechanism to prevent Railway free tier from sleeping

'use strict';

const express = require('express');
const cors    = require('cors');

const app  = express();
const PORT = process.env.PORT || 3000;
const START_TIME = Date.now();

// Activity tracking
let requestCount = 0;
let lastActivity = Date.now();
const activityLog = [];

app.use(cors());
app.use(express.json({ limit: '1mb' }));

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
  // Keep only last 1000 entries
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

// Ping endpoint (simple response)
app.get('/ping', (req, res) => {
  res.json({ pong: true, ts: Date.now() });
});

// Keep-alive endpoint (POST - generates write activity)
app.post('/keepalive', (req, res) => {
  const { source, ts } = req.body || {};
  res.json({
    status: 'kept-alive',
    source: source || 'unknown',
    received: ts || Date.now(),
    serverTime: Date.now()
  });
});

// Status endpoint (detailed)
app.get('/status', (req, res) => {
  res.json({
    name: 'NoxExplorer Gateway',
    version: '1.0.0',
    uptime: Math.floor((Date.now() - START_TIME) / 1000),
    requests: requestCount,
    lastActivity: new Date(lastActivity).toISOString(),
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
    endpoints: ['/health', '/ping', '/keepalive', '/status', '/activity', '/analyze'],
    note: 'This service stays awake via GitHub Actions keep-alive bug'
  });
});

// Analyze endpoint (main functionality)
app.post('/analyze', (req, res) => {
  const { classes, game } = req.body;
  if (!classes || !Array.isArray(classes)) {
    return res.status(400).json({ error: 'classes array required' });
  }
  
  // For now, return a stub - real AI integration comes later
  res.json({
    code: '-- NoxExplorer generated stub\nprint("AI analysis pending - classes: ' + classes.length + '")',
    classes_analyzed: classes.length,
    game: game || 'unknown'
  });
});

// Self-ping mechanism (the bug)
// Pings itself every 2 minutes to generate activity and prevent sleep
setInterval(() => {
  const selfPing = async () => {
    try {
      const fetch = (await import('node-fetch')).default;
      const res = await fetch(`http://localhost:${PORT}/ping`, {
        method: 'GET',
        timeout: 5000
      });
      if (res.ok) {
        console.log(`[self-ping] OK at ${new Date().toISOString()}`);
      }
    } catch (err) {
      // Silent fail - self-ping is best effort
    }
  };
  selfPing();
}, 120_000); // Every 2 minutes

// Start server
app.listen(PORT, () => {
  console.log(`[nox] Railway server running on :${PORT}`);
  console.log(`[nox] Self-ping active every 2 minutes`);
  console.log(`[nox] Keep-alive endpoints: /health, /ping, /keepalive, /status`);
});
