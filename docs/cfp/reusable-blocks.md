# Reusable CfP blocks

Copy-paste snippets for new proposals. Combine with [`submissions/enterprise-agentops-rhoai.md`](submissions/enterprise-agentops-rhoai.md) or [`template.md`](template.md).

## Key message

```
Your Agent. Our Platform. Production-Ready.
```

BYOA from the Red Hat AI Agentic Strategy 2026: the agent harness (OpenClaw) is interchangeable; the platform stack is not.

## Titles

**Primary (saved base):**

```
Enterprise AgentOps: Secure BYOA Agent Platform on Red Hat OpenShift AI
```

**Alternatives:**

```
Production AgentOps on RHOAI: Sandbox, Zero-Trust Credentials, and Full Traceability
```

```
Bring Your Own Agent — Run It Safely on OpenShift AI
```

## One-line problem statement

```
Many enterprises want autonomous AI agents, but security teams block adoption due to credential leaks, uncontrolled OS execution, and missing audit trails.
```

## Platform pillars (bullet form)

Use 3–4 in abstracts; full set in comments or long proposals.

```
- Sandbox containment: OpenClaw runs in an Agent Sandbox with Landlock file locks and OpenShell egress policies.
- Zero-trust credentials: All outbound traffic routes through OpenShell Gateway; inference.local injects API keys so agents never see raw secrets.
- AI guardrails: NeMo Guardrails (TrustyAI) filter requests/responses before MaaS inference.
- Full observability: MLflow captures agent reasoning, tool calls, and LLM hops for compliance tracing.
```

## Business value (closing line)

```
Business value: unlocks agentic AI adoption by solving security, credential isolation, and auditability in one platform stack.
```

## Live demo scenarios (A–D)

For **Comments** or session outline:

```
Live interactive demo: Four scripted security scenarios — credential exfiltration attempt, filesystem access (/etc/shadow), selective egress opening, and NeMo Guardrails blocking prompt injection — with real-time sandbox blocking and MLflow trace visibility.
```

| Scenario | Story | Platform proof |
|----------|-------|----------------|
| A · Credentials | Agent tries to exfiltrate API keys | OpenShell gateway key vault; keys never in sandbox |
| B · Files | Access to `/etc/shadow` | Landlock file locks |
| C · Egress | Default deny → allow google.com | OpenShell egress policy change |
| D · Guardrails | Prompt injection | NeMo Guardrails (TrustyAI) before MaaS |

## Multi-platform alignment (Comments)

```
Multi-platform alignment: Red Hat OpenShift, RHOAI 3.x (MLflow, TrustyAI, MaaS), Agent Sandbox Operator (OLM), OpenShell, and RHEL kernel security (Landlock).
```

## Links

| Label | URL |
|-------|-----|
| Presenter companion (v5) | https://davidseve.github.io/agentops-showcase/demo/v5/live.html#step-0 |
| Repository | https://github.com/davidseve/agentops-showcase |
| Architecture (local) | `docs/demo/v5/live.html` step **Overall Demo** |

## TDP mapping (Red Hat TLDR)

| TDP | Rationale |
|-----|-----------|
| Virtualization | OpenShift / RHOAI on virtualized or cloud infrastructure |
| Container Management | Agent Sandbox Operator, OLM, sandbox pods, OpenShell on OCP |
| Automation | GitOps-ready Helm deploy, scripted demo lifecycle |
| AI Platform | RHOAI 3.x, MaaS, MLflow, TrustyAI / NeMo Guardrails |

## Suggested form defaults

| Field | Recommendation |
|-------|----------------|
| Format | Presentation/Demonstration |
| Duration | 60 min (50 + 10 break) — core demo ~10 min + architecture + Q&A |
| Categories | Product and Solutions Focus; Experience Reports |
| Audience | Specialist |
| Level | Intermediate |
| Capacity | 0 (unlimited virtual) |

## Short abstract (~100 words)

Trimmed from the base submission for strict word limits:

```
Security teams block agentic AI over credential leaks, uncontrolled execution, and missing audit trails. This session demos production AgentOps on Red Hat OpenShift AI 3.x for safe BYOA workloads: Agent Sandbox with Landlock and OpenShell egress; zero-trust credentials via the gateway and inference.local key injection; NeMo Guardrails before MaaS; MLflow traces for compliance. Live scenarios show blocked exfiltration, filesystem denial, controlled egress, and guardrail enforcement. Outcome: adopt autonomous agents without sacrificing isolation or observability.
```

(~95 words)
