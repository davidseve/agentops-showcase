# CfP submission — KubeCon + CloudNativeCon Europe 2027 (Barcelona)

> Sessionize form: https://sessionize.com/kubecon-cloudnativecon-europe-2027/
> Source CFP page: https://events.linuxfoundation.org/kubecon-cloudnativecon-europe/program/cfp/

## Metadata

| Field | Value |
|-------|-------|
| Event | KubeCon + CloudNativeCon Europe 2027 — 15–18 March, Barcelona, Spain |
| Submission deadline | **Sunday, 11 October, 11:59 PM CEST (UTC+2)** |
| Notifications | Monday, 7 December |
| Status | draft |
| Based on | `enterprise-agentops-rhoai.md` (reframed for a Kubernetes/CNCF audience — no Red Hat product-pitch framing) |

> ⚠️ Deadline is **less than a week away** from today (2026-10-05).

---

## Submit your session

**Selected:** Brand new session

## Session Title *

Title Case, as it will appear on the schedule.

```
Bring Your Own Agent: Sandboxing, Zero-Trust Credentials, and Observability for AI Agents on Kubernetes
```

Alternatives considered:

```
Your Agent, Our Sandbox: Running AI Agents Safely on Kubernetes
```

```
Secure BYOA: Sandboxing, Zero-Trust Credentials, and Observability for Agentic Workloads
```

## Description * (max 1000 characters)

Third person, no product sales pitch — written as a Kubernetes-native pattern, not a vendor demo. Commits to MCP/SPIFFE/A2A as part of the **live demo by event date**, not as "already built today" (see [What's Next](#whats-next-committed-for-the-live-demo-by-march-2027) below for what that commitment actually requires). (~990 characters)

```
Enterprises want autonomous AI agents in production, but security teams often block adoption: agents execute arbitrary code, hold long-lived credentials, and leave no audit trail when things go wrong.

This session presents a Kubernetes-native reference architecture for running any agent framework safely (Bring-Your-Own-Agent): the harness is interchangeable, the security/observability layer is not. It covers sandboxed execution with kernel-level file/network policies, zero-trust credentials injected at a gateway so the agent never holds a raw secret, guardrails filtering requests/responses before the model, and full tracing of every reasoning step, tool call, and model hop.

By event time, the same foundation also adds governed tool access via MCP, SPIFFE-based cryptographic agent identity, and A2A multi-agent delegation — demoed live alongside four blocked attack scenarios: credential exfiltration, filesystem access, uncontrolled egress, and prompt injection.
```

### Description — Variant B (conditional: use only if MCP Gateway + SPIFFE ship, A2A doesn't)

**Do not use this variant unless it's actually true at submission time.** Same honesty rule as the primary description above: anything stated in present tense here must be real and live-demoable, not "designed" or "in progress." If by the time you're about to click submit, `ROADMAP.md` Phase 5.1 (MCP Gateway) and Phase 5.2 (SPIFFE/SPIRE) checklists are actually done and validated end-to-end, but Phase 5.3 (A2A) is not — swap the primary description above for this one instead of editing it in place, so there's a clear diff of what changed and why. (996 characters)

```
Enterprises want autonomous AI agents in production, but security teams often block adoption: agents execute arbitrary code, hold long-lived credentials, and leave no audit trail when things go wrong.

This session presents a Kubernetes-native reference architecture for running any agent framework safely (Bring-Your-Own-Agent): the harness is interchangeable, the security/observability layer is not. Agents run sandboxed with kernel-level file/network policies and hold no static secrets - a gateway exchanges a SPIFFE identity for short-lived tokens - while every tool call is governed through an MCP gateway with per-tool authorization and rate limiting. Guardrails filter requests/responses before the model, and traces cover every reasoning step and tool call.

A live demo shows five scenarios blocked in real time: credential exfiltration, filesystem access, uncontrolled egress, prompt injection, and an unauthorized tool call.
```

Diffs from the primary description if you switch to this variant:

| Item | Primary (today, nothing shipped) | Variant B (MCP + SPIFFE shipped, A2A not) |
|---|---|---|
| MCP Gateway | Future commitment ("by event time ... adds") | Present tense, described as a live mechanism ("governed through an MCP gateway with per-tool authorization") |
| SPIFFE/SPIRE | Future commitment | Present tense ("a gateway exchanges a SPIFFE identity for short-lived tokens") |
| A2A | Bundled into the same future commitment | Pulled out, kept as an explicit forward-looking closer only — **not** described as built |
| Demo scenarios | 4 | 5 — adds an MCP-governed "unauthorized tool call" scenario, since there's now something real to show there |
| What's Next section | All 3 items tracked as 0% | Update the table: mark Phase 5.1/5.2 rows as shipped with evidence (link to the ADR / validation run), keep Phase 5.3 as the only "committed for X" row |

## Submitting for *

**Selected:** KubeCon + CloudNativeCon (standard conference session, reviewed by the Program Committee)

_(Not a CNCF Project Opportunity submission.)_

## Agreements * (all required)

- [x] **Content Quality Agreement** — not AI-generated slop; this is an original technical talk based on a real build.
- [x] **Code of Conduct** — reviewed.
- [x] **Commitment to Inclusivity** — Inclusive Speaker Orientation + Inclusive Language Initiative reviewed.
- [x] **Speaker Gender Representation** — N/A, only 2 speakers (requirement applies at 3+).
- [x] **Speaker Submission Limit Acknowledgement** — confirm ≤3 submissions to this CFP.

---

## Speaker 1 (primary)

| Field | Value |
|-------|-------|
| Name | David Severiano |
| Email | davidseve16@gmail.com |
| Job title shown publicly | AppDev and DevOps Architect in Red Hat |
| Bio (public, ≤500 chars) | AppDev and DevOps Architect in Red Hat, helping customers to adopt Open Source and facilitating innovation, modernization, and agility inside the company. |
| Speaker Title field | AppDev and DevOps Architect |
| Company | Red Hat |
| Company Website | https://www.redhat.com |
| End user organization? | No — Red Hat is a vendor, not an [end user company](https://landscape.cncf.io/?group=members&view-mode=card&classify=category&enduser=true) |
| Country of residence | Spain |
| Spoken previously (LF/CNCF event)? | No — first time |
| Person of color / Gender identity / Other underrepresented group | Left blank (optional, confidential — not required for review) |

## Speaker 2 (co-speaker)

```
ccornejo@redhat.com
```

Carlos Cornejo will receive a Sessionize invitation to join as co-speaker. Confirm his public bio/title/photo in his own Sessionize profile before submission — not something this doc can fill in for him.

## Format *

KubeCon submission types (not the Red Hat TLDR scale used elsewhere in this kit):

- [x] **Session Presentation** — 30 minutes, 1–2 speakers
- [ ] Panel Discussion — 30 min, 3–5 speakers
- [ ] Lightning Talk — 5 min, 1 speaker
- [ ] Poster Session — digital, 1–2 presenters
- [ ] Tutorial — 80 min hands-on, 1–5 speakers

## Track *

- [x] **Agentic AI**
- [ ] AI Inference and Infrastructure
- [ ] Security
- [ ] Observability
- [ ] Platform Engineering: Infrastructure & Delivery
- [ ] (other tracks — see full list in `../cfp` source doc)

Rationale: the talk is squarely agent architecture + AgentOps + sandboxing + observability for agentic workloads on Kubernetes — the exact language of the Agentic AI track description. The MCP/SPIFFE/A2A commitment hits two more keywords from that same track blurb ("MCP, Agent Skills, A2A, tool integration ... identity and security"), reinforcing track fit.

## What's Next (committed for the live demo by March 2027)

Pulled from [`../../ROADMAP.md` § Phase 5 — Platform Enhancements (Q3/Q4 2026 Roadmap)](../../ROADMAP.md). **Status as of this submission (2026-10-05): all three items are at 0 of their listed tasks done ("Not started" in the roadmap).** The description above commits to having them live-demoable by the event (15–18 March 2027, ~5 months of runway) — that is a real delivery commitment this submission creates, not a description of today's state. Track progress against the task checklists in `ROADMAP.md` Phase 5.1/5.2/5.3 and update this table as work lands.

| Roadmap item | What it adds | Target | Progress tracking |
|---|---|---|---|
| **MCP Gateway integration** (Phase 5.1, P1) | Single gateway federates/governs tool access across MCP servers: `MCPServerRegistration` aggregation, OAuth2/JWT auth via Kuadrant `AuthPolicy`, per-tool CEL/OPA authorization, `RateLimitPolicy` rate limiting. Envoy + Gateway API + Istio + Connectivity Link. | Live by March 2027 | `ROADMAP.md` Phase 5.1 checklist (0/9 done) |
| **SPIFFE/SPIRE agent identity** (Phase 5.2, P1) | Replaces the static `apiKey: "unused"` + gateway-injected-secret model with cryptographic agent identity: sandbox supervisor exchanges a SPIRE JWT-SVID for a short-lived, endpoint-specific bearer token; the agent process never sees the SVID or socket. | Live by March 2027 | `ROADMAP.md` Phase 5.2 checklist (0/7 done) |
| **A2A multi-agent delegation** (Phase 5.3, P2) | Agent-to-agent task delegation over the A2A protocol; the sandboxed agent publishes an `AgentCard` and can delegate to peer agents through the same gateway/identity layer. | Live by March 2027 | `ROADMAP.md` Phase 5.3 checklist (0/5 done) |

**Accountability check before actually submitting this form:** if there is any real doubt these three items will be live and demoable by March 2027 (not just "designed"), either (a) pull this paragraph from the description and keep only what's demoed today, or (b) soften to "the architecture is designed to extend to..." — but do **not** submit the committed-by-event phrasing above unless the team genuinely intends to execute Phase 5.1–5.3 on that timeline. A committee acceptance based on this description obligates delivering it live.

Possible use if there's a free-text "Comments to organizers" field beyond the 1000-char description: paste the table above (trimmed) there instead of relying only on the one-sentence commitment in the public abstract.

## Additional Sessionize fields (not in Red Hat template)

| Field | Value |
|-------|-------|
| Is this a case study? | Yes — real-world build/experience report, not theoretical |
| Presented before at an LF/CNCF event in the past year? | No |
| CNCF-hosted (graduated/incubating/sandbox) or OSS projects referenced | Kubernetes (demoed today). Committed for the live demo by event date via Phase 5.1: Envoy, Istio, and **Kuadrant** (CNCF Sandbox — "Connectivity Link" is the downstream product name, don't use that name in the CNCF-projects list). If the Phase 5.1 work isn't actually done by submission-finalization time, update this row and the description to stop referencing them as part of the session. |
| Additional Resources | Link to a prior talk recording if available, else a short self-intro video per CFP guidance. **TODO**: attach link before submitting. |
| Slides commitment | Accepted speakers must submit slides pre-event — note for scheduling prep work. |

## Comments / internal notes (do not submit as-is)

- This description intentionally avoids a Red Hat-product-first framing (no "RHOAI", "OpenShell", "OpenClaw" brand names in the public-facing text) to fit CNCF's "avoid sales/marketing pitches" guidance — reuse the **pattern**, not the product names, in the abstract. Internal comments to the program committee (if a free-text field exists beyond description) can name the concrete stack.
- If a separate "Comments to organizers" field exists in the actual Sessionize form (not visible in the fields pasted by the user), port over the multi-platform alignment + demo scenario table from [`../reusable-blocks.md`](../reusable-blocks.md).
- Before final submit: confirm Carlos Cornejo is under his own 3-submission cap for this CFP.
- Photo: Sessionize speaker profile photo is reused from account — verify it's current.
