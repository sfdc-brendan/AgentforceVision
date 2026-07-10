/*
 * Minimal signed-cookie admin session. No external session store required.
 * A token is `expiryMs.hmac(expiryMs)` signed with SESSION_SECRET. We also
 * compare the admin password in constant time.
 */
import crypto from 'crypto';

const COOKIE_NAME = 'av_admin';
const TTL_MS = 12 * 60 * 60 * 1000; // 12 hours

function secret() {
  // Falls back to a per-boot random secret (sessions drop on restart, which is
  // acceptable for a single-admin demo). Set SESSION_SECRET in prod to persist.
  if (!global.__AV_SECRET) {
    global.__AV_SECRET = process.env.SESSION_SECRET || crypto.randomBytes(32).toString('hex');
  }
  return global.__AV_SECRET;
}

function sign(value) {
  return crypto.createHmac('sha256', secret()).update(value).digest('hex');
}

export function passwordMatches(input) {
  const expected = process.env.ADMIN_PASSWORD || '';
  if (!expected) return false;
  const a = Buffer.from(String(input));
  const b = Buffer.from(expected);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}

export function issueToken() {
  const expiry = String(Date.now() + TTL_MS);
  return `${expiry}.${sign(expiry)}`;
}

export function verifyToken(token) {
  if (!token || typeof token !== 'string') return false;
  const [expiry, mac] = token.split('.');
  if (!expiry || !mac) return false;
  const expected = sign(expiry);
  const a = Buffer.from(mac);
  const b = Buffer.from(expected);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return false;
  return Date.now() < Number(expiry);
}

export function parseCookies(header) {
  const out = {};
  if (!header) return out;
  for (const part of header.split(';')) {
    const idx = part.indexOf('=');
    if (idx === -1) continue;
    const k = part.slice(0, idx).trim();
    const v = part.slice(idx + 1).trim();
    out[k] = decodeURIComponent(v);
  }
  return out;
}

export function isAuthed(req) {
  const cookies = parseCookies(req.headers.cookie);
  return verifyToken(cookies[COOKIE_NAME]);
}

export function setSessionCookie(res, secure) {
  const attrs = [
    `${COOKIE_NAME}=${issueToken()}`,
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    `Max-Age=${Math.floor(TTL_MS / 1000)}`,
  ];
  if (secure) attrs.push('Secure');
  res.setHeader('Set-Cookie', attrs.join('; '));
}

export function clearSessionCookie(res, secure) {
  const attrs = [`${COOKIE_NAME}=`, 'Path=/', 'HttpOnly', 'SameSite=Lax', 'Max-Age=0'];
  if (secure) attrs.push('Secure');
  res.setHeader('Set-Cookie', attrs.join('; '));
}

export function adminEnabled() {
  return Boolean(process.env.ADMIN_PASSWORD);
}
