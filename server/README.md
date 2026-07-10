# Vireon demo site server + admin usage dashboard

A tiny Node/Express server that:

1. Serves the public demo site from `local-demo/`.
2. Records anonymous usage events (`POST /api/track`).
3. Powers a password-protected usage dashboard at **`/admin`**.

There is no build step and only two runtime dependencies (`express`, `pg`).

## What gets tracked

Events are anonymous — no cookies for visitors, no personal data, no third
parties. A random visitor id lives in the browser's `localStorage` purely to
count unique visitors; the server stores only a salted hash of the IP.

| Event | When it fires |
|-------|---------------|
| `pageview` | Every page load |
| `settings_open` | Visitor opens the "Connect your agent" / Settings dialog |
| `agent_connected` | A saved Embedded Messaging snippet loads on the page |
| `chat_ready` | Salesforce Embedded Messaging widget finishes loading |
| `chat_open` | Visitor maximizes/opens the chat window |
| `chat_close` | Visitor minimizes/closes the chat window |

> Note on chat events: `chat_ready` / `chat_open` / `chat_close` rely on the
> Salesforce Embedded Messaging (MIAW) lifecycle events the widget dispatches on
> `window`. Deeper, message-level analytics aren't exposed to the host page by
> the native widget — for that you'd use Salesforce reporting / session data.

## Environment variables

See `.env.example`. The important ones:

- `ADMIN_PASSWORD` — **required** to enable `/admin`. If unset, the dashboard and
  stats API are disabled.
- `SESSION_SECRET` — signs the admin session cookie and salts the IP hash. Set a
  long random value.
- `DATABASE_URL` — Postgres connection. If unset, an in-memory store is used
  (data resets on every restart).

## Run locally

```bash
npm install
ADMIN_PASSWORD=devpass SESSION_SECRET=dev node server/index.js
# open http://localhost:8080  and  http://localhost:8080/admin
```

Without `DATABASE_URL` it uses the in-memory store, so you can click around the
site and immediately see numbers in `/admin`.

## Deploy on Heroku

Your app currently serves the static site. These steps switch it to the Node
server (which serves the same site plus tracking + admin). From the repo root:

```bash
# 1. Make sure Heroku uses the Node buildpack (auto-detected from package.json).
heroku buildpacks:set heroku/nodejs -a <your-app>

# 2. Add Postgres so stats persist across restarts (free/essential tier is fine).
heroku addons:create heroku-postgresql:essential-0 -a <your-app>
#    This sets DATABASE_URL automatically.

# 3. Set the admin password and a session secret.
heroku config:set ADMIN_PASSWORD='a-strong-password' -a <your-app>
heroku config:set SESSION_SECRET="$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")" -a <your-app>

# 4. Deploy.
git add .
git commit -m "Add usage tracking + admin dashboard"
git push heroku main   # or: git push heroku <branch>:main
```

Then visit `https://<your-app>.herokuapp.com/admin` and log in with
`ADMIN_PASSWORD`.

The `Procfile` (`web: node server/index.js`) tells Heroku how to boot it.

## How auth works

`/admin/login` compares the submitted password to `ADMIN_PASSWORD` in constant
time, then issues an HMAC-signed, HttpOnly session cookie (12h TTL). No session
store or user table needed. `/api/stats` requires that cookie.
