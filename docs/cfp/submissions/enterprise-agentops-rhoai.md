# Enterprise AgentOps on RHOAI — base CfP

| Field | Value |
|-------|-------|
| Saved | 2026-03 |
| Status | base (reuse for future CfPs) |
| Event | _(fill when submitting)_ |

Canonical reusable blocks: [`../reusable-blocks.md`](../reusable-blocks.md)

---

## Title *

```
Enterprise AgentOps: Secure BYOA Agent Platform on Red Hat OpenShift AI
```

## Abstract *

Keep this short — around 100 words.

```
Many enterprises want autonomous AI agents, but security teams block adoption due to credential leaks, uncontrolled OS execution, and missing audit trails.

This session demos a production-grade AgentOps platform on Red Hat OpenShift AI (RHOAI) 3.x that enables safe Bring Your Own Agent (BYOA) workloads:

- Sandbox containment: OpenClaw runs in an Agent Sandbox with Landlock file locks and OpenShell egress policies.
- Zero-trust credentials: All outbound traffic routes through OpenShell Gateway; inference.local injects API keys so agents never see raw secrets.
- AI guardrails: NeMo Guardrails (TrustyAI) filter requests/responses before MaaS inference.
- Full observability: MLflow captures agent reasoning, tool calls, and LLM hops for compliance tracing.

Business value: unlocks agentic AI adoption by solving security, credential isolation, and auditability in one platform stack.
```

## Speakers emails *

```
dseveria@redhat.com, ccornejo@redhat.com
```

## Format *

The TLDR will be virtual — running off standard Google Meet or similar technology.

Defined styles and typical duration:

- Presentation/Demonstration (25 or 50 mins)
- Topic Discussion (25 or 50 mins)
- Hands-on (110, 240 mins)

**Selected:** Presentation/Demonstration

## Duration (minutes) *

Slot options (session + break):

| Minutes | Session + break |
|---------|-----------------|
| 10 | 9 + 1 (lightning, groups of 3) |
| 30 | 25 + 5 |
| 60 | 50 + 10 |
| 120 | 110 + 10 (hands-on) |
| 240 | 240 embedded breaks (workshop) |

**Selected:** 60

## Topic Categories *

- Experience Reports — Lessons learned working with a customer, in the community or collaborating inside Red Hat.
- Product and Solutions Focus — Red Hat products and solutions portfolio
- Business, Leadership, Culture & Soft Skills
- Open Source Spotlight
- The Mix

**Selected:**

- [x] Experience Reports
- [x] Product and Solutions Focus

## TDP *

Red Hat Technology Decision Points alignment:

| TDP | Selected |
|-----|----------|
| Server/Cloud Operating System | |
| Virtualization | ✓ |
| Container Management | ✓ |
| Application Platform | |
| Automation | ✓ |
| AI Platform | ✓ |
| NO TDP | |

## Target audience *

**Selected:** Specialist

_(Options: Specialist · Generalist · Non-technical · All)_

## Level *

**Selected:** Intermediate

_(Options: Foundational · Intermediate · Advanced · Expert)_

## Capacity *

```
0
```

Unlimited for virtual session.

## Comments *

```
Multi-platform alignment: Red Hat OpenShift, RHOAI 3.x (MLflow, TrustyAI, MaaS), Agent Sandbox Operator (OLM), OpenShell, and RHEL kernel security (Landlock).

Live interactive demo: Four scripted security scenarios — credential exfiltration attempt, filesystem access (/etc/shadow), selective egress opening, and NeMo Guardrails blocking prompt injection — with real-time sandbox blocking and MLflow trace visibility.

Presenter companion UI: architecture map and observability panel for a guided walkthrough (not required for attendees) https://davidseve.github.io/agentops-showcase/demo/v5/live.html#step-0

Key message: Your Agent. Our Platform. Production-Ready. — BYOA from the Red Hat AI Agentic Strategy 2026; the agent harness (OpenClaw) is interchangeable; the platform stack is not.

Repo: https://github.com/davidseve/agentops-showcase
```

---

## Copy-paste bundle (plain text)

For forms that use a single text area:

```
Title: Enterprise AgentOps: Secure BYOA Agent Platform on Red Hat OpenShift AI

Abstract:
Many enterprises want autonomous AI agents, but security teams block adoption due to credential leaks, uncontrolled OS execution, and missing audit trails.

This session demos a production-grade AgentOps platform on Red Hat OpenShift AI (RHOAI) 3.x that enables safe Bring Your Own Agent (BYOA) workloads:

- Sandbox containment: OpenClaw runs in an Agent Sandbox with Landlock file locks and OpenShell egress policies.
- Zero-trust credentials: All outbound traffic routes through OpenShell Gateway; inference.local injects API keys so agents never see raw secrets.
- AI guardrails: NeMo Guardrails (TrustyAI) filter requests/responses before MaaS inference.
- Full observability: MLflow captures agent reasoning, tool calls, and LLM hops for compliance tracing.

Business value: unlocks agentic AI adoption by solving security, credential isolation, and auditability in one platform stack.

Speakers: dseveria@redhat.com, ccornejo@redhat.com
Format: Presentation/Demonstration | Duration: 60 min | Virtual (Google Meet)
Categories: Experience Reports, Product and Solutions Focus
TDP: Virtualization, Container Management, Automation, AI Platform
Audience: Specialist | Level: Intermediate | Capacity: 0

Comments:
Multi-platform alignment: Red Hat OpenShift, RHOAI 3.x (MLflow, TrustyAI, MaaS), Agent Sandbox Operator (OLM), OpenShell, and RHEL kernel security (Landlock).

Live interactive demo: Four scripted security scenarios — credential exfiltration attempt, filesystem access (/etc/shadow), selective egress opening, and NeMo Guardrails blocking prompt injection — with real-time sandbox blocking and MLflow trace visibility.

Presenter companion UI: https://davidseve.github.io/agentops-showcase/demo/v5/live.html#step-0

Key message: Your Agent. Our Platform. Production-Ready.

Repo: https://github.com/davidseve/agentops-showcase
```
