/*
 * Public Vireon / Agentforce Vision demo site + usage tracking + admin dashboard.
 *
 * Routes:
 *   GET  /                 -> static site (local-demo/)
 *   POST /api/track        -> record a usage event (public, from the site)
 *   GET  /admin            -> login page or dashboard (HTML)
 *   POST /admin/login      -> exchange password for a session cookie
 *   POST /admin/logout     -> clear session cookie
 *   GET  /api/stats        -> aggregated usage JSON (auth required)
 */
import express from 'express';
import crypto from 'crypto';
import path from 'path';
import { fileURLToPath } from 'url';
import { createStore, KNOWN_TYPES } from './store.js';
import {
  adminEnabled,
  clearSessionCookie,
  isAuthed,
  passwordMatches,
  setSessionCookie,
} from './auth.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');
const SITE_DIR = path.join(ROOT, 'local-demo');
const ADMIN_HTML = path.join(__dirname, 'public', 'admin.html');

const PORT = process.env.PORT || 8080;
const store = createStore();

const app = express();
app.set('trust proxy', 1);
app.use(express.json({ limit: '16kb' }));

function isSecure(req) {
  return req.secure || req.headers['x-forwarded-proto'] === 'https';
}

function hashIp(req) {
  const ip = (req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').split(',')[0].trim();
  const salt = process.env.SESSION_SECRET || 'av-demo-salt';
  return crypto.createHmac('sha256', salt).update(ip).digest('hex').slice(0, 16);
}

function clip(v, max) {
  if (v == null) return null;
  return String(v).slice(0, max);
}

/* ------------------------------------------------------------- tracking API */

app.post('/api/track', async (req, res) => {
  try {
    const b = req.body || {};
    if (!KNOWN_TYPES.includes(b.type)) {
      return res.status(400).json({ ok: false, error: 'unknown event type' });
    }
    await store.recordEvent({
      type: b.type,
      visitorId: clip(b.visitorId, 64),
      sessionId: clip(b.sessionId, 64),
      path: clip(b.path, 512),
      referrer: clip(b.referrer, 512),
      userAgent: clip(req.headers['user-agent'], 512),
      ipHash: hashIp(req),
      meta: b.meta && typeof b.meta === 'object' ? b.meta : null,
    });
    res.json({ ok: true });
  } catch (err) {
    console.error('[track] error', err);
    res.status(500).json({ ok: false });
  }
});

/* -------------------------------------------------------------------- admin */

app.get('/admin', (req, res) => {
  res.sendFile(ADMIN_HTML);
});

app.post('/admin/login', (req, res) => {
  if (!adminEnabled()) {
    return res.status(503).json({ ok: false, error: 'Admin is not configured. Set the ADMIN_PASSWORD env var.' });
  }
  const { password } = req.body || {};
  if (!passwordMatches(password)) {
    return res.status(401).json({ ok: false, error: 'Incorrect password.' });
  }
  setSessionCookie(res, isSecure(req));
  res.json({ ok: true });
});

app.post('/admin/logout', (req, res) => {
  clearSessionCookie(res, isSecure(req));
  res.json({ ok: true });
});

app.get('/api/stats', async (req, res) => {
  if (!adminEnabled()) {
    return res.status(503).json({ ok: false, error: 'Admin is not configured. Set the ADMIN_PASSWORD env var.' });
  }
  if (!isAuthed(req)) {
    return res.status(401).json({ ok: false, error: 'Not authenticated.' });
  }
  const days = Math.min(Math.max(parseInt(req.query.days, 10) || 30, 1), 90);
  try {
    const stats = await store.getStats({ days });
    res.json({ ok: true, stats });
  } catch (err) {
    console.error('[stats] error', err);
    res.status(500).json({ ok: false, error: 'Failed to load stats.' });
  }
});

/* --------------------------------------------------------------- static site */

app.use(express.static(SITE_DIR, { extensions: ['html'] }));

// SPA-ish fallback: any unmatched GET returns the site's index.
app.get('*', (req, res) => {
  res.sendFile(path.join(SITE_DIR, 'index.html'));
});

async function main() {
  await store.init();
  app.listen(PORT, () => {
    console.log(`[server] listening on :${PORT}`);
    console.log(`[server] admin ${adminEnabled() ? 'ENABLED' : 'DISABLED (set ADMIN_PASSWORD)'}`);
  });
}

main().catch((err) => {
  console.error('[server] fatal', err);
  process.exit(1);
});
