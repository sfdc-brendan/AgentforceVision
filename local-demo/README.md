# Agentforce Vision - Local Demo

A tiny, dependency-free web page you can run on your own machine to demo Agentforce Vision. It hosts a branded landing page and loads **Salesforce's native Enhanced Messaging widget** - so photo/file upload works out of the box and connects straight to your Agentforce agent.

There is **no backend and no credentials to manage**. You paste your Embedded Messaging **code snippet** in Settings; it's stored only in your browser (localStorage), and the page injects it so the messaging widget boots.

> This is optional. It's a convenience for local demos and is completely separate from the Salesforce metadata in this repo. The agent, prompt template, Apex, and Knowledge are what actually power the experience (see the [main README](../README.md)).

## Prerequisites

1. You've deployed and activated the agent from this repo (`../install.sh`) and set up a **Messaging for In-App and Web (Enhanced Messaging)** channel for it.
2. You've created an **Embedded Service Deployment** for that channel using the **Custom Client** type. When you first create the deployment you're asked to choose **Web**, **Mobile**, or **Custom Client** - you must pick **Custom Client**, because that's the type that generates the pasteable bootstrap snippet this demo uses (Web/Mobile do not).
3. In Setup -> **Messaging Settings** -> your channel -> Edit, enable **"Let customers send attachments to agents"** so the upload button appears in the chat.
4. In Setup -> **Embedded Service Deployments** -> your Custom Client deployment, add this page's origin (for example `http://localhost:8080`) to the allowed/trusted origins (CORS). Otherwise the widget won't load on localhost.
5. Have your deployment's **Install Code** snippet handy (Setup -> Embedded Service Deployments -> your Custom Client deployment -> "Install Code"). It contains `embeddedservice_bootstrap.init(...)` and a `bootstrap.min.js` script tag.

## Run it

From this folder, serve the files over `http://localhost` (opening the file directly with `file://` will not work for the messaging widget):

```bash
cd local-demo
python3 -m http.server 8080
# or: npx serve -l 8080
```

Then open <http://localhost:8080> and:

1. Click **Settings** (or "Connect your agent").
2. Paste your Embedded Messaging code snippet and click **Save & connect**.
3. The page reloads, Salesforce's chat button appears in the corner, and the status badge shows "Assistant connected."
4. Open the chat, attach a photo of a device or error screen, and ask the agent to take a look.

> Tip: the port must match whatever origin you allowlisted in step 3. If you serve on a different port, add that origin too.

## How it works

The page parses your pasted snippet and re-creates its `<script>` tags at runtime (scripts injected via `innerHTML` don't execute). The inline script that defines `initEmbeddedMessaging` runs first, then the external `bootstrap.min.js` loads and calls it - exactly as if the snippet were hard-coded in the page. Everything after that (chat UI, file upload, session, routing to your agent) is Salesforce's native Enhanced Messaging.

To disconnect or switch orgs, open Settings and click **Clear & disconnect**.

## Files

```
index.html   Branded landing page + Settings modal
app.js        Snippet storage, validation, and injection
styles.css    Standalone Vireon-styled CSS (no build step)
```
