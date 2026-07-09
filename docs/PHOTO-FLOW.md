# What happens when a customer uploads a photo

A plain-language, step-by-step walkthrough of the photo-troubleshooting flow — from the moment a customer uploads an image in chat to the grounded troubleshooting steps that come back. For the architecture diagram and the "why" behind each design choice, see [How it works](../README.md#how-it-works) in the main README.

## The flow, step by step

- **Photo lands in Salesforce**
  - The customer uploads the photo through the chat/web experience; it's stored as a Salesforce File (`ContentDocument`) linked to their messaging session — not as a raw chat attachment. They mention it in chat ("here's a photo").

- **Agent Router picks the lane**
  - The agent reads the message and, seeing a visible problem / uploaded photo, routes to the **Photo Troubleshooting** subagent.

- **Guardrail check**
  - The subagent only proceeds if a photo was *actually* uploaded (not just described in words). This prevents it from analyzing an unrelated image and giving a wrong answer.

- **Analyze Image action fires** (`apex://AgentforceVisionImageAction`)
  - Shows "Analyzing your photo…" to the user.
  - Apex finds the most recent image on that session, sends it to the **Flex prompt template bound to the multimodal model** (via native `ConnectApi.EinsteinLLM`, behind the Trust Layer).
  - The model returns two things: a **DIAGNOSIS** (what it sees + likely problem) and **KEYWORDS** (search terms). Keywords get stashed in a variable; the diagnosis is passed back to the agent.

- **Agent explains what it sees**
  - It tells the customer in plain language what the photo shows and the most likely issue (from the diagnosis).

- **Find Articles action fires** (`apex://AgentforceVisionKnowledgeAction`)
  - Shows "Searching Vireon knowledge…".
  - Uses the model's keywords to **SOSL-search Knowledge**, then a **relevance filter** (`VisionArticleRelevance`) drops false matches (e.g. a clothes-dryer photo matching a "hair dryer" article on the word "dryer"), returning only genuinely relevant article content.

- **Grounded troubleshooting comes back**
  - The agent composes the fix using **only the returned article content** — no invented steps. If nothing matches, it gives safe general guidance and offers a human.

- **Escalation path (if needed)**
  - At any point the customer can ask for a person → the agent opens a Service Cloud case and hands off to a "specialist" subagent that logs notes and resolves the case.

## In one line

Upload → router → (guardrail) → multimodal model diagnoses the image → keywords → grounded Knowledge search → plain-language diagnosis + article-backed steps, with a human-escalation fallback — all orchestrated natively by Agentforce.

## Why it's possible

There is **no custom-trained vision model**. The "vision" is Salesforce's stock multimodal model (`sfdc_ai__DefaultGPT55`) reached through native platform APIs. Everything clever is in the wiring:

- **Multimodal LLM behind the Einstein Trust Layer** — a general vision-capable model, not a bespoke classifier.
- **A Flex prompt template with a file input** — the Models API can't take images directly, so a prompt template that accepts a `ContentDocument` is the supported path to feed the model an image. The prompt forces a structured `DIAGNOSIS:` / `KEYWORDS:` response so the output is machine-usable.
- **An Apex action orchestrator** (`AgentforceVisionImageAction`) — resolves the uploaded image and calls the template via `ConnectApi.EinsteinLLM`.
- **Retrieval + a relevance guard** (`AgentforceVisionKnowledgeAction` + `VisionArticleRelevance`) — keeps the answer grounded in real Knowledge and drops false keyword matches.

All intelligence — vision, reasoning, and knowledge grounding — runs on the Salesforce platform, governed by the Trust Layer.
