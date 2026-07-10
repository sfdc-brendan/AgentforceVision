/*
 * Agentforce Vision - local demo glue.
 *
 * Stores the user's Embedded Messaging code snippet in localStorage and injects
 * it so Salesforce's native messaging widget loads and connects to their agent.
 * No backend and no credentials - the snippet is all Salesforce needs.
 */
const STORAGE_KEY = 'av_esw_snippet';

const $ = (id) => document.getElementById(id);
const modal = $('settingsModal');
const badge = $('statusBadge');
const errEl = $('err');

function openModal() {
  $('snippet').value = localStorage.getItem(STORAGE_KEY) || '';
  errEl.hidden = true;
  modal.hidden = false;
}
function closeModal() {
  modal.hidden = true;
}

function setStatus(connected) {
  badge.dataset.state = connected ? 'on' : 'off';
  badge.textContent = connected ? 'Assistant connected' : 'Assistant not connected';
}

// Basic sanity check that this looks like an Embedded Messaging snippet.
function validate(html) {
  if (!html || !html.trim()) return 'Please paste your Embedded Messaging snippet.';
  if (!/embeddedservice_bootstrap/.test(html)) {
    return "That doesn't look like an Embedded Messaging snippet (no 'embeddedservice_bootstrap').";
  }
  if (!/bootstrap\.min\.js/.test(html)) {
    return "Missing the 'bootstrap.min.js' script tag - paste the full snippet.";
  }
  return '';
}

// Re-create the snippet's <script> tags so the browser actually executes them
// (innerHTML-injected scripts do not run). Inline scripts first (they define
// initEmbeddedMessaging), then the external bootstrap with its onload.
function injectSnippet(html) {
  const doc = new DOMParser().parseFromString(html, 'text/html');
  const scripts = Array.from(doc.querySelectorAll('script'));
  const inline = scripts.filter((s) => !s.src);
  const external = scripts.filter((s) => s.src);
  for (const s of [...inline, ...external]) {
    const el = document.createElement('script');
    el.setAttribute('data-esw-injected', 'true');
    if (s.src) {
      el.src = s.src;
      el.async = false;
      const onload = s.getAttribute('onload');
      if (onload) el.setAttribute('onload', onload);
    } else {
      el.textContent = s.textContent;
    }
    document.body.appendChild(el);
  }
}

function save() {
  const html = $('snippet').value;
  const msg = validate(html);
  if (msg) {
    errEl.textContent = msg;
    errEl.hidden = false;
    return;
  }
  localStorage.setItem(STORAGE_KEY, html.trim());
  // Reload so the widget boots cleanly from a fresh page (avoids double-init).
  location.reload();
}

function clearSnippet() {
  localStorage.removeItem(STORAGE_KEY);
  location.reload();
}

// Wire up UI.
$('settingsBtn').addEventListener('click', openModal);
$('heroSettingsBtn').addEventListener('click', openModal);
$('saveBtn').addEventListener('click', save);
$('clearBtn').addEventListener('click', clearSnippet);
document.querySelectorAll('[data-close]').forEach((el) => el.addEventListener('click', closeModal));
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape' && !modal.hidden) closeModal();
});

// Show the current origin in the prereqs hint so users know what to allowlist.
const originHint = $('originHint');
if (originHint) originHint.textContent = location.origin;

// On load: if a snippet is saved, connect.
const saved = localStorage.getItem(STORAGE_KEY);
if (saved) {
  setStatus(true);
  injectSnippet(saved);
} else {
  setStatus(false);
  openModal();
}
