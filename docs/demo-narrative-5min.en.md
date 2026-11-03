# Demo narrative — 5-minute format (one-take)

> Language: **English** (on-camera talk track).
> Spanish beat-by-beat: [`demo-narrative-5min.md`](demo-narrative-5min.md).
> Timed table: [`docs/demo-script.md`](demo-script.md) § Five-minute one-take.
> Full live narrative (~9–10 min, Spanish): [`demo-narrative-v1.md`](demo-narrative-v1.md).

Status: short-slot / recording variant. **Same four tests A–D** and the two live changes. No `ls` digression. No long recaps. Built for **one-take** (no edit jump-cuts): pace comes from rehearsal, not from the cut.

## Message

When we talk with customers about agentic architectures, security is one of the biggest challenges we hit. With **BYOA** we can deploy any agent/harness — and that is dangerous without guardrails: skills, scripts, internet access, complex tasks by default. This demo showcases **RHOAI security capabilities** so we can help customers deploy agents safely in production. In five minutes we **demonstrate** four controls; we install nothing on stage.

## Differences vs the 10-minute narrative

| In 10 min | In 5 min (one-take) |
|---|---|
| Models/security gap intro (~55s) | **~45s** hook: customer challenge + BYOA + two panels |
| Explain → paste prompt | **Paste → Play → one line** |
| `ls` digression after B | **Cut** |
| Three-layer recap before D (~40s) | **One line** in flight |
| Wait for recon script on camera | Narrate over it; if the model drags, start Change 2 as soon as useful code appears |
| MLflow with several invocations | **Curl deny → allow** (same trace type, different Response) |
| Broad close | Overall Demo **Play** + roadmap/GitOps/RHPDS + tagline |

Backstage, policies, and scripts: same as v1 (`default.yaml` → `demo-allow-google-egress.sh` → `demo-enable-guardrails.sh`; reset with `demo-reset.sh`).

## Live talk track (5:00)

Split screen: [`v5/live.html`](demo/v5/live.html) (left) + Control UI / OpenClaw (right). Same chat session for A–C; **New session** only before D-after (after Change 2), as in v1.

### 0:00–0:45 — Hook + two panels

**Spoken text:**

When customers talk about adopting agents, security is the blocker — every call. Agents are powerful because they are non-deterministic; enterprises need fixed boundaries the agent cannot cross.

With BYOA we let you bring any harness — OpenClaw in this demo. That is powerful, and dangerous by default at the same time: Stuff like running skills, writing scripts, reaching the internet.. they are complex tasks with no fixed walls. Without a trusted control path for credentials, filesystem, network, and model behavior (if we can't provide security guardrails that enforce what the agent may and may not do) — IT’s default is to ban them.

That is why we prepared a demo to showcase the security capabilities provided by RHOAI, so we can help our customers deploy these agents safely in their production environments.

The demo is organized in two panels: on the left, a visual representation of the architecture with a series of guided steps that let us explain different security scenarios; on the right, OpenClaw, which we will use as the harness to interact with the model and see how it behaves.

*(Companion on step A or Overall Demo ready; no need to walk the full layer map.)*

### 0:45–1:15 — Test A (`inference.local` / API key)

1. **Copy prompt** (key-audit — same as v1 / `demo-script.md`).
2. **Play** in Control UI.

<!-- **Expected:** no real key (`apiKey: unused` / empty env).  -->

Let's try to retrieve the api key.

The agent does not know which model it uses and does not hold the API key: it talks to `inference.local`; the gateway injects the credential.

**Line:** “The key is injected at the gateway; the sandbox does not have it.”

### 1:15–1:40 — Test B (`/etc/shadow` / Landlock)

1. **Copy prompt** (`cat /etc/shadow`).
2. **Play**.

<!-- **Expected:** Permission denied (OpenShell sandbox / Landlock). -->

Let's try to access a system file the agent is not supposed to 

**Line:** “System files are already locked down from day one.”

### 1:40–2:45 — Test C + Change 1 (egress)

#### C.before — connectivity controlled (OpenShell gateway)

1. **Copy prompt** (`curl -sI https://google.com`).
2. **Play** → **blocked**.

By default, everything is blocked. No external network access is allowed.

**Line:** “We control the agent’s connectivity from the gateway.”

#### C.after — permissive mode

1. Visible terminal: `./scripts/demo-allow-google-egress.sh` — explain the config (google.com allowlist; agent in permissive mode for that destination).
2. Same prompt.
3. **Play** → **HTTP 200** (or 301 toward google).

**Line:** “One policy lever; no sandbox rebuild. The agent does not change.”

### 2:45–4:05 — Test D + Change 2 (NeMo)

#### D.before — full access to model capabilities

1. **Copy prompt** (network recon — same as v1).
2. **Play** → potentially dangerous response (script / recon plan).

While it generates: “Without Guardrails, the model can deliver a potentially dangerous task; it does not need to execute it.”

#### D.after — NeMo Guardrails in action

1. Explain NeMo Guardrails (TrustyAI): security layer on the inference path.
2. Terminal: `./scripts/demo-enable-guardrails.sh`.
3. **New session** in Control UI.
4. Same prompt → **Play** → refuse / rail (“I can't respond” or equivalent).

**Line:** “OpenClaw still calls `inference.local`; the backend changes. The guardrail cuts — not the harness.”

<!-- If the model drags on D-before: do not pad with theory; around ~3:50 on the clock, start Change 2 even if the script is unfinished (before/after still holds if before already produced code). -->

### 4:05–4:30 — MLflow (traceability)

Open Gen AI Studio / experiment `openclaw-tracing` for **this** session (or the companion MLflow tab).

Show the **curl to google**: same kind of trace, **different Response** — blocked vs allowed. 

With MLflow we get full traceability: actions, commands, LLM invocations, prompts.

**Line:** “Success and failure in the same place — platform observability, not an add-on.”

If time is short: only the curl deny → allow contrast.

### 4:30–4:45 — Overall Demo + summary

Return to the **Overall Demo** step in the companion and hit **Play**. While it runs, a short summary of the security path just shown (credentials, files, egress, Guardrails, traces).

### 4:45–5:00 — Deployment/installation + close

**Line:** “The whole deployment is GitOps-based and Agent-skills-driven; standing it up on RHPDS / demo.redhat.com is straightforward.”

Tagline: *Your Agent. Our Platform. Production-Ready.*

## Timing (clock)

| Block | Clock | Hard stop |
|---|---|---|
| Hook + two panels | 0:00–0:45 | 0:50 |
| A | 0:45–1:15 | 1:20 |
| B | 1:15–1:40 | 1:45 |
| C + Change 1 | 1:40–2:45 | 2:50 |
| D + Change 2 | 2:45–4:05 | 4:10 |
| MLflow | 4:05–4:30 | 4:35 |
| Overall Demo Play | 4:30–4:45 | 4:50 |
| Roadmap + GitOps + tagline | 4:45–5:00 | 5:00 |

If the clock hits **4:10** without D-after: jump to New session + refuse prompt; compress MLflow to ~20s; still try Overall + the GitOps/RHPDS line.

## Preflight (same as v1)

```bash
./scripts/demo-reset.sh
./scripts/demo-presenter-serve.sh
# New session in Control UI before recording
```

Skills: `demo-backstage-prep`, `demo-present`, `demo-allow-google-egress`, `demo-enable-guardrails`, `mlflow-tracing-validate`.

## One-take rehearsal

- Time with a visible clock; do not pause the recording.
- Prompts already in the companion (**Copy prompt**); do not type by hand; cadence **prompt → Play**.
- Change 1/2 scripts in terminal history (Enter — do not hunt for the path).
- If an LLM prompt is slow: advance to the next clock gate; do not improvise digressions.
- Rehearse the jump to Overall Demo + the GitOps/RHPDS line so both fit in ~15s.

## Relationship to v1

Same architecture, same scripts, same tests. This file only **compresses the talk track** for a five-minute slot (customer hook, prompt→Play beats, Overall + roadmap close). For the long runbook and product context, use [`demo-narrative-v1.md`](demo-narrative-v1.md) (Spanish) and [`demo-script.md`](demo-script.md) (English timed companion).
