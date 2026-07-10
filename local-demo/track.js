/*
 * Lightweight, privacy-respecting usage tracker for the Vireon demo site.
 *
 * Sends small events to /api/track on the same origin. A random visitor id is
 * kept in localStorage (for unique-visitor counts) and a session id in
 * sessionStorage. No personal data, cookies, or third parties involved.
 *
 * It also listens for Salesforce Embedded Messaging (MIAW) window events to
 * record when the chat widget becomes ready and when a visitor opens/closes it.
 */
(function () {
  var VISITOR_KEY = 'av_visitor_id';
  var SESSION_KEY = 'av_session_id';

  function uuid() {
    try {
      if (crypto && crypto.randomUUID) return crypto.randomUUID();
    } catch (e) {}
    return 'v-' + Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 10);
  }

  function getVisitorId() {
    var id = localStorage.getItem(VISITOR_KEY);
    if (!id) { id = uuid(); localStorage.setItem(VISITOR_KEY, id); }
    return id;
  }

  function getSessionId() {
    var id = sessionStorage.getItem(SESSION_KEY);
    if (!id) { id = uuid(); sessionStorage.setItem(SESSION_KEY, id); }
    return id;
  }

  function send(type, meta) {
    var payload = {
      type: type,
      visitorId: getVisitorId(),
      sessionId: getSessionId(),
      path: location.pathname + location.search,
      referrer: document.referrer || '',
      meta: meta || null,
    };
    var body = JSON.stringify(payload);
    try {
      if (navigator.sendBeacon) {
        navigator.sendBeacon('/api/track', new Blob([body], { type: 'application/json' }));
        return;
      }
    } catch (e) {}
    // Fallback for browsers without sendBeacon.
    fetch('/api/track', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: body,
      keepalive: true,
    }).catch(function () {});
  }

  // Public hook so page glue (app.js) can log domain events.
  window.AVTrack = { event: send };

  // Page view on load.
  send('pageview');

  // Settings interactions (buttons live in index.html).
  document.addEventListener('click', function (ev) {
    var t = ev.target.closest ? ev.target.closest('#settingsBtn, #heroSettingsBtn') : null;
    if (t) send('settings_open');
  });

  // Salesforce Embedded Messaging lifecycle events fire on window.
  window.addEventListener('onEmbeddedMessagingReady', function () { send('chat_ready'); });
  window.addEventListener('onEmbeddedMessagingWindowMaximized', function () { send('chat_open'); });
  window.addEventListener('onEmbeddedMessagingWindowMinimized', function () { send('chat_close'); });
})();
