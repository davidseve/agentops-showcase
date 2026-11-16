# CfP submission: Red Hat Summit 2027 lab

| Field | Value |
|-------|-------|
| Event | Red Hat Summit 2027 (Boston, 24–27 May 2027) |
| Form | RainFocus CFP (Labs) |
| Guide | [Red Hat Summit 2027 CFP guide](https://static.rainfocus.com/redhat/sum27/static/staticfile/staticfile/Red%20Hat%20Summit%202027%20-%20CFP%20guide_1790091751783001fmzt.pdf) (lab example LB1347, p. 40) |
| Deadline | 30 November 2026, 11:59 PM PT |
| Status | draft |
| Based on | [`enterprise-agentops-rhoai.md`](enterprise-agentops-rhoai.md), [`../reusable-blocks.md`](../reusable-blocks.md) |
| Session type | Labs (90 min, up to 3 instructors) |
| Instructors | David Severiano, Carlos Cornejo |

Attendees work on a **pre-provisioned** Red Hat OpenShift AI cluster. They reproduce platform controls (scenarios A–D and an MLflow trace). They do not bootstrap the stack from the repository.

---

## Title *

Sentence case. AgentOps names the practice. Red Hat OpenShift AI is the product.

```
AgentOps: secure bring-your-own-agent on Red Hat OpenShift AI
```

## Abstract *

Pattern from the Summit 2027 lab example (LB1347): audience hook, hands-on sentence, task bullets, outcome, who it is for. Third person except the opening address used in that example. No "we".

```
Do you already know the basics of Red Hat OpenShift AI and want the controls security teams require before an agent reaches production? Then this lab is for you.

This lab offers a hands-on introduction to AgentOps on Red Hat OpenShift AI: the controls for running a bring-your-own-agent workload in production. On a pre-provisioned cluster, attendees complete these tasks:

- Confirm that model API keys stay in the OpenShell gateway and never appear inside the agent sandbox.
- Confirm that Landlock file locks block access to sensitive host paths such as /etc/shadow.
- Change the egress policy from default deny to an allowlisted destination, then retest outbound access.
- Switch inference through NeMo Guardrails on TrustyAI and retest an unsafe prompt.
- Inspect the same session in MLflow, including requests, responses, and tool calls.

After this lab, attendees can name the AgentOps controls required to run an interchangeable agent harness on Red Hat OpenShift AI without giving the agent raw credentials, unrestricted files, or open egress, and they can point to one audit trail for both allowed and denied actions. This lab is suitable for anybody with at least basic Red Hat OpenShift and Red Hat OpenShift AI experience.
```

**Abstract word count:** 199.

## Speakers emails *

```
dseveria@redhat.com, ccornejo@redhat.com
```

Submitter must add each instructor as a speaker (the submitter is not listed automatically) and confirm both can travel to Boston, 24–27 May 2027.

## RainFocus taxonomy

| Field | Selection |
|-------|-----------|
| Session type | Labs |
| Duration | 90 minutes |
| Primary topic | agentic AI |
| Additional topics (up to 3) | security, generative AI, containers |
| Primary product | Red Hat AI |
| Additional products (up to 3) | Red Hat OpenShift; community projects |
| Primary audience | Manage AI architectures and strategy |
| Technical proficiency | Technical, intermediate |
| Industry | relevant to all industries (leave unset) |

OpenShell is not a Red Hat product family in the 2027 list. Call it out in comments, not as a primary product. NeMo Guardrails is delivered through the TrustyAI component of Red Hat OpenShift AI.

## Lab outline (90 min)

| Minutes | Block | Attendee task |
|---------|-------|----------------|
| 0–10 | Orientation | Map the pre-provisioned stack: agent sandbox, OpenShell gateway, inference, guardrails, MLflow. |
| 10–25 | Credentials (A) | Ask the agent for its API key and model secret. Confirm the key is absent from the sandbox and injected at the gateway. |
| 25–40 | Files (B) | Ask the agent to read `/etc/shadow`. Confirm Landlock denies the path. |
| 40–55 | Egress (C) | Curl an external host and see default deny. Apply the allowlist change, then retest and see the allow. |
| 55–70 | Guardrails (D) | Repeat a reconnaissance-style prompt on direct inference, then switch the inference path to NeMo Guardrails and retest. |
| 70–82 | Trace | Open the same session in MLflow and compare an allow and a deny. |
| 82–90 | Close | Restate the control pattern: policy around the agent, one audit trail. Reset notes for the next sitting if needed. |

Instructor scripts (not run by attendees as a full install): `scripts/demo-warmup.sh`, `scripts/demo-allow-google-egress.sh`, `scripts/demo-enable-guardrails.sh`, `scripts/demo-reset.sh`.

## Lab technical requirements (AI labs, new for 2027)

| Requirement | Value |
|-------------|-------|
| Room | Summit lab room: hardwired laptops, Red Hat in-room assistants by lab size |
| Cluster | One pre-provisioned Red Hat OpenShift cluster per lab (or a shared cluster with one project per attendee). Red Hat OpenShift AI installed. Agent sandbox and OpenShell gateway already running. |
| Attendee work | Browser to the agent control UI and MLflow. Prescribed prompts. No cluster bootstrap, no GPU, no local model weights. |
| Inference | Prefer a model from the approved Red Hat Demo Platform (RHDP) AI models-as-a-service list for Summit 2027 labs. The exercises need **tool calling** (file, network, and prompt tests). Any approved tool-calling model is acceptable. |
| Model outside the list | Use only if no approved model supports tool calling. Justification: the lab checks platform controls around the agent (credential injection, file lock, egress, guardrails, trace). It does not depend on a specific vendor model. Direct GPU access is not required. |
| Secrets | Lab keys live in the gateway, not in the attendee workspace and not in the public repository. |
| Reset | Instructors return the sandbox to direct inference and default-deny egress between sittings. |

Select the exact RHDP model name in RainFocus when the approved list is visible on the form. Do not paste a production API key into the submission.

## RainFocus lab fields (paste)

Character counts checked against the form limits (outline 1821/2000, outcomes 538/800).

### Comprehensive outline

```
Pre-provisioned Red Hat OpenShift AI cluster. Attendees use a browser only. They do not install OpenShift, Red Hat OpenShift AI, or the agent. Instructors reset the sandbox between sittings.

0-10 min. Orientation.
Walk the AgentOps path on the pre-built stack: agent sandbox, OpenShell gateway, inference, NeMo Guardrails on TrustyAI, and MLflow. State the lab rule: the agent harness stays the same. The platform controls change.

10-25 min. Credentials.
Each attendee asks the agent to reveal its model API key and environment secrets. Expected result: no key in the sandbox. The agent calls inference.local. The gateway injects the credential. Attendees record where the key is and where it is not.

25-40 min. Files.
Each attendee asks the agent to read /etc/shadow. Expected result: permission denied by Landlock. Attendees note that the lock is already in place. It is not added after the failed prompt.

40-55 min. Egress.
Each attendee asks the agent to request an external HTTPS host. Expected result: denied by the default egress policy. Instructors apply an allowlist for that host. Attendees repeat the same request and see it allowed. Attendees record both results.

55-70 min. Guardrails.
Attendees send a reconnaissance-style prompt on the direct inference path and observe the model respond. Instructors switch inference.local to NeMo Guardrails. Attendees start a new session, send the same prompt, and see the guardrail block it. The agent harness is not rewritten.

70-82 min. Trace.
Attendees open MLflow for that session and find one allow and one deny, including the request, the response, and the tool calls.

82-90 min. Close.
Attendees restate the four AgentOps controls and the single audit trail. Instructors reset the sandbox to direct inference and default-deny egress for the next sitting.
```

### Actionable outcomes (5)

```
1. Show that a model API key is absent from the agent sandbox and is injected only at the OpenShell gateway.
2. Show that Landlock denies the agent read access to /etc/shadow, with no change to the agent.
3. Change egress from default deny to one allowlisted host and show the same request move from blocked to allowed.
4. Switch inference through NeMo Guardrails and show an unsafe prompt blocked without rewriting the agent harness.
5. Open the MLflow trace for that session and point to one allow and one deny in the same audit trail.
```

### Primary environment

Pick the dropdown value for a pre-provisioned Red Hat OpenShift cluster with Red Hat OpenShift AI. Do not pick a GPU workbench or a bare Red Hat Enterprise Linux seat. Attendees need a browser to the agent UI and to MLflow.

### AI model

Select: **Yes, and the model(s) I need are available Model-as-a-Service options.**

The lab needs one chat model with tool calling so the agent can try a file read, an outbound HTTPS request, and an unsafe prompt. It does not need a GPU, and it does not depend on a specific vendor. If the linked list has no tool-calling chat model, switch to **Yes, but the model(s) I need are not included** and add:

```
The lab requires a chat model with tool calling so the agent can attempt a file read, an outbound HTTPS request, and an unsafe prompt. No model on the approved list exposes tool calling. Direct GPU access is not required. Any tool-calling chat model is acceptable. The exercises check AgentOps platform controls, not model quality.
```

## Comments * (paste if the form has a comments or requirements field)

```
Hands-on AgentOps lab on a pre-provisioned Red Hat OpenShift AI cluster. Attendees do not install the platform. They verify four controls and one trace: gateway credential injection, Landlock file denial, egress allowlist change, NeMo Guardrails on TrustyAI, and MLflow request/response visibility.

Primary product: Red Hat AI. Also uses Red Hat OpenShift. OpenShell is the sandbox gateway used for egress and credential injection (community / non-Red Hat component; not selected as the primary product).

Inference uses models-as-a-service with tool calling. Prefer an approved RHDP AI MaaS model. No attendee GPU.

Repository (architecture, policies, instructor scripts): https://github.com/davidseve/agentops-showcase
Presenter companion (instructors only): https://davidseve.github.io/agentops-showcase/demo/v5/live.html#step-0
```

---

## Copy-paste bundle (plain text)

```
Title: AgentOps: secure bring-your-own-agent on Red Hat OpenShift AI

Abstract:
Do you already know the basics of Red Hat OpenShift AI and want the controls security teams require before an agent reaches production? Then this lab is for you.

This lab offers a hands-on introduction to AgentOps on Red Hat OpenShift AI: the controls for running a bring-your-own-agent workload in production. On a pre-provisioned cluster, attendees complete these tasks:

- Confirm that model API keys stay in the OpenShell gateway and never appear inside the agent sandbox.
- Confirm that Landlock file locks block access to sensitive host paths such as /etc/shadow.
- Change the egress policy from default deny to an allowlisted destination, then retest outbound access.
- Switch inference through NeMo Guardrails on TrustyAI and retest an unsafe prompt.
- Inspect the same session in MLflow, including requests, responses, and tool calls.

After this lab, attendees can name the AgentOps controls required to run an interchangeable agent harness on Red Hat OpenShift AI without giving the agent raw credentials, unrestricted files, or open egress, and they can point to one audit trail for both allowed and denied actions. This lab is suitable for anybody with at least basic Red Hat OpenShift and Red Hat OpenShift AI experience.

Session type: Labs
Duration: 90 minutes
Primary topic: agentic AI
Additional topics: security; generative AI; containers
Primary product: Red Hat AI
Additional products: Red Hat OpenShift; community projects
Primary audience: Manage AI architectures and strategy
Proficiency: Technical, intermediate
Speakers: dseveria@redhat.com, ccornejo@redhat.com

Comments:
Hands-on AgentOps lab on a pre-provisioned Red Hat OpenShift AI cluster. Attendees do not install the platform. They verify four controls and one trace: gateway credential injection, Landlock file denial, egress allowlist change, NeMo Guardrails on TrustyAI, and MLflow request/response visibility.

Inference uses models-as-a-service with tool calling. Prefer an approved RHDP AI MaaS model. No attendee GPU.

Repository: https://github.com/davidseve/agentops-showcase
```

---

## Internal notes (do not submit)

- Angles to stress: prescribed tasks and a pre-baked cluster. The catalog abstract is not a product tour.
- Sections to shorten: if RainFocus caps the abstract, drop the MLflow bullet last and keep credentials, files, egress, and guardrails.
- Hands-on prerequisites: basic Red Hat OpenShift and Red Hat OpenShift AI. No Ansible-style expert bar. Attendees need a browser only.
- Capacity: leave to the labs team (room size and hardwired laptops). Do not promise a number in the abstract.
- Fail paths: if the model is slow, instructors narrate over the run and move to the next control. Reset with `scripts/demo-reset.sh` before the next sitting.
- Post-acceptance (not this draft): lab workbook steps, RHDP provisioning, and the exact approved MaaS model name on the form.
- Sub-programming: optional. This proposal is a core Labs session, not a DevZone lightning talk.
