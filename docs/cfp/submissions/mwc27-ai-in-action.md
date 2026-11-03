# MWC Barcelona 2027 — AI in Action (joint + demo)

| Field | Value |
|-------|-------|
| Event | MWC Barcelona 2027 |
| Form | https://www.mwcbarcelona.com/become-a-speaker |
| Deadline | 5 November 2026, 23:00 CET |
| Theme | **AI in Action** |
| Status | draft — ready to paste |
| Based on | AgentOps live demo ([`demo-narrative-5min.en.md`](../../demo-narrative-5min.en.md)) |
| RH planning | Independent entry (outside PR strategic list) |
| Roles | **Speakers:** David Severiano + Carlos M. Cornejo · **Submitter:** Carlos M. Cornejo (GSMA emails submitter only) |

---

## Paste into Red Hat Google Doc (template box)

```
Title:
When the Agent Can Touch the Network: Hardening Agentic Ops Live

Q: Is your submission for a moderator role, solo, joint or panel presentation?
Joint

Will your submission include a demonstration?
Yes

What is your key objective from speaking?
Show CSP practitioners and technology leaders what it actually takes to move an agentic system from an unconstrained PoC into production-safe controls—without rewriting the agent—so they leave with a concrete control pattern they can demand of any platform or partner before agents sit near network-adjacent or operational systems.

Which Key Theme does your submission best fit into? Select one:
AI in Action

Submission Overview
Please provide a SHORT summary of your submission (200 word limit)

Enterprises and CSPs are putting agentic AI next to care, OSS tooling, and network-adjacent workflows. Speed is the upside; an agent that can run skills, scripts, and outbound calls by default is the downside security teams fear. Most demos show the happy path. This one shows the control path.

In a short live demonstration, we start with a working "bring your own agent" system and harden it in public: credentials that never enter the sandbox; filesystem isolation that blocks host secrets; selective egress that opens only what policy allows; an inference guardrail path that stops unsafe generations without rewriting the agent; and full request/response traces so allow and deny share one audit trail.

The takeaway is not a product tour. It is the operational pattern telco architects need before agents sit near production systems: policy around the agent, not hope inside the model—and the questions to demand of any partner claiming production-ready agentic AI.

Submitter info
Carlos M. Cornejo
Senior Architect
ccornejo@redhat.com

Speaker's Information
David Severiano
Mr.
Senior Architect
dseveria@redhat.com
Red Hat

Co-speaker
Carlos M. Cornejo
Mr.
Senior Architect
ccornejo@redhat.com
Red Hat
```

**Overview word count:** ~154 (under 200).

---

## Paste into GSMA form (field map)

Use the same text as above. The public form exposes one speaker block — put **David** there. Add Carlos as co-speaker in any free-text / notes field if the form allows. Speakers are named in form fields only (not in the Overview).

| GSMA field | Value |
|------------|-------|
| Submitter's First Name | Carlos |
| Submitter's Last Name | Cornejo |
| Submitter's Job Title | Senior Architect |
| Submitter's Email | ccornejo@redhat.com |
| Submitter's Company Name | Red Hat |
| Industry Description | SOFTWARE PROVIDER |
| Country / Region | Spain |
| Speaker's Prefix | Mr. |
| Speaker's First Name | David |
| Speaker's Last Name | Severiano |
| Speaker's Job Title | Senior Architect |
| Speaker's Email | dseveria@redhat.com |
| Speaker's Company Name | Red Hat |
| Co-speaker (Overview / notes) | Carlos M. Cornejo, Senior Architect, ccornejo@redhat.com |
| Submission Title | When the Agent Can Touch the Network: Hardening Agentic Ops Live |
| Format | **Joint** |
| Submission Overview | _(block above — 200 word limit)_ |
| Demonstration | **Yes** |
| Key objective | _(block above)_ |
| Key Theme | **AI in Action** |
| Consider for other programmes | Yes (optional tick) |

Alternate titles:

```
Bring Your Own Agent to the Telco Stack—Without Bringing Your Own Breach
```

```
Policy Around the Agent: Operationalizing Secure Agentic AI for CSPs
```

---

## Demo outline (notes for Google Doc / rehearsal — do not paste all into Overview)

1. **Hook (~45s):** CSPs put agents next to care/OSS/network-adjacent workflows; BYOA unlocks speed and uncontrolled tool use by default; this session hardens a live agent instead of hiding risk.
2. **Live controls (same agent):**
   - Credentials never in the sandbox (gateway injects at inference)
   - Filesystem isolation blocks host secrets
   - Egress deny → selective allowlist (same prompt, different outcome)
   - Inference guardrail path cuts unsafe generations without rewriting the agent
   - Request/response traces: deny and allow in one audit trail
3. **Close:** Same agent; controls on the platform path. Tagline: *Your Agent. Our Platform. Production-Ready.*

Timed talk track: [`demo-narrative-5min.en.md`](../../demo-narrative-5min.en.md) (~5 min one-take). Full runbook: [`demo-script.md`](../../demo-script.md).

---

## Audience takeaways (Google Doc Notes — not required on form)

1. Ungoverned agents near telco workflows industrialize risk faster than value.
2. Prefer platform controls (sandbox, egress, inference rails, traces) over rewriting every harness.
3. Demand before/after proof: same prompt, different policy outcome.
4. Observability of deny *and* allow is part of the control story.

---

## Positioning vs other Red Hat AI in Action / Trust entries (internal only)

| Sibling entry | Their angle | This entry |
|---------------|-------------|------------|
| Rimma Iontel (panel) | “Is it safe to let AI run the network?” governance debate | Live **operational** before/after — what safe looks like on stage |
| Kush Kochgaway (solo) | Document → deploy agent *pipelines* for telco delivery | **Runtime** hardening of a running agent (not delivery pipelines) |
| Honoré / Telenor / NVIDIA (panel) | Sovereign AI Factory at scale / ROI | Practitioner field report + demo, not factory economics |
| Chris Wright (Trust at Scale) | Strategic open-source / community defense; may mention sandboxing | Operator-visible failure modes and policy levers — not a CTO keynote frame |

Do **not** pitch product names as the story. Do **not** claim ownership of OpenShell. Story = control pattern around BYOA for CSP / network-adjacent workloads.

---

## Submit checklist

1. Paste the template box into the Red Hat MWC speakership Google Doc (create **your own box** — do not overwrite the TEMPLATE).
2. Optional: soft-review with Amy/Chelsea/Jessie if you want PR visibility; not required for independent entries.
3. Open https://www.mwcbarcelona.com/become-a-speaker — copy from this file into the form (do not draft only in the browser).
4. Tick demonstration **Yes**, theme **AI in Action**, format **Joint**. Form speaker block: `dseveria@redhat.com`; submitter: `ccornejo@redhat.com`; co-speaker in notes if available (names stay out of Overview).
5. Submit before **5 November 2026, 23:00 CET**.
6. Keep the confirmation email; GSMA contacts the **submitter** only. Share status with David. Outcome emails: late November 2026 (unsuccessful) or further review if silent.
7. After submit: set Status above to `submitted` and date it.

Contact if form fails twice: conferenceprogramming@gsma.com
