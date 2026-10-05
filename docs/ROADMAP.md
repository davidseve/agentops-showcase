# Roadmap - AgentOps Demo

## Phase 0 - Foundation

- [x] Generate `AGENTS.md` - project context, stack, constraints
- [x] Generate `docs/ROADMAP.md` - this roadmap
- [x] Create `README.md` with project overview
- [x] Initial commit and push to GitHub

## Phase 1 - Research and Validation

- [x] Research RHOAI 3.x component availability and versions
- [x] Deploy RHOAI 3.x with required dependencies on target cluster
- [x] Add deploy waits (CSV, DSCI, CRDs) and post-deploy validation (`make validate`)
- [x] Fix cleanup order (DSCI before operator) and add cleanup validation (`make validate-cleanup`)
- [x] Document cluster bootstrap (RHOAI platform deploy) — see [cluster-bootstrap.md](cluster-bootstrap.md)
- [x] Document OpenShell local install (macOS and Linux) — see [openshell-installation.md](openshell-installation.md)
- [x] Add `scripts/install-openshell.sh` — one-command local stack installer (macOS and Linux)
- [x] Add `scripts/uninstall-openshell.sh` — remove local OpenShell stack (macOS and Linux)
- [x] Validate OpenShell deployment method and constraints on target cluster — see [openshell-installation.md § OpenShift](openshell-installation.md#openshift--rhoai-cluster-deployment) (chart `0.0.83`, TLS + certgen hook on OCP; post-install mTLS sync via `make openshell-sync-mtls`)
- [x] NeMo Guardrails integration: via TrustyAI operator — see [ADR-0004](adr/0004-nemo-guardrails-via-trustyai.md)
- [x] Establish ADR process and retroactive records — see [docs/adr/](adr/README.md)
- [x] OGX: confirmed GA
- [x] InstallPlan approval: Manual policy with auto-approve in Makefile (ADR-0008)
- [x] Dashboard race fixes: wait-dashboard-crd, adopt-dashboard-config (ADR-0008)
- [x] MLflow chart: OpenClaw integration RBAC + experiment Job (gated, Phase 5 activates)
- [x] Document MaaS options available in demo.redhat.com
- [x] Map each demo feature to Red Hat product/component — [AGENTS.md](../AGENTS.md) § Technology-to-Product Mapping; topology in [AGENT-SANDBOX-AND-OPENSHELL.md](AGENT-SANDBOX-AND-OPENSHELL.md) and [demo/overall-demo-architecture.html](demo/overall-demo-architecture.html)
- [x] Document initial pinned versions manifest (operator CSVs, image tags/digests)



## Phase 1.5 - OpenShell + OpenClaw Integration

- [x] Deploy OpenShell from OCI Helm chart (ADR-0003)
- [x] Define OpenShell auth strategy: nginx mTLS bridge + OpenClaw password auth (ADR-0011; oauth-proxy dropped 2026-08-06)
- [x] Configure Agent Sandbox SCC requirements
- [x] Deploy OpenClaw as agent harness inside sandbox
- [x] Configure sandbox network policy
- [x] Configure MaaS provider and credential injection
- [x] Validate access, MaaS connectivity, and sandbox enforcement
- [x] Wire MLflow tracing from OpenClaw plugin (ADR-0010)
- [x] Secrets management strategy: `secrets/secrets.env` gitignored (never committed — verified clean history). Migrated to OpenShell's inference router (`inference.local`): LLM credentials now live exclusively in the gateway's provider record, injected by the inference router at the gateway layer. The sandbox process uses `apiKey: "unused"` and never sees the real key. Previously used OpenClaw's `${LITELLM_API_KEY}` SecretRef (2026-08-13), now superseded by inference router (2026-08-14). Also fixed: stale-gateway kill step used `oc exec` (wrong PID namespace vs. the `openshell sandbox exec`-started gateway), so old processes were never actually killed on restart — see [AGENT-SANDBOX-AND-OPENSHELL.md § Step 1](AGENT-SANDBOX-AND-OPENSHELL.md#step-1--clean-stale-gateway-processes-via-openshell-sandbox-exec-sandbox-context).
- [x] Validate traces visible in RHOAI Dashboard Gen AI Studio — confirmed via Playwright (`tests/mlflow-ui.spec.ts`), including full Request/Response content from a live E2E chat
- [x] TrustyAI + kserve set to `Managed` on the shared DataScienceCluster ahead of need (EvalHub red-teaming, Phase 3 guardrails, future model serving) — both confirmed `Ready: True` end-to-end (2026-08-14), applied via a one-off `oc apply`/`oc patch` against the live cluster. `values.yaml` was updated so `kserve.managementState: Managed` (alongside the already-`Managed` `trustyai`/`mlflowoperator`) reflects the real desired state declaratively for any future `make deploy-platform` from-scratch install. One operational note from getting it to `Ready`: after flipping `kserve` from `Removed → Managed`, the `TrustyAI` component CR's own controller only re-evaluated its `InferenceServices CRD does not exist` precondition failure once (at the moment `kserve`'s CRDs were still being installed) and then sat requeue-backed-off; annotating the parent `DataScienceCluster` didn't re-trigger it, but annotating the child `trustyai.components.platform.opendatahub.io/default-trustyai` CR directly did force an immediate re-reconcile, after which it went `Ready: True` in ~20s. One-off unblock, not automated (CRDs won't disappear again once installed).
- [x] Removed all shared-cluster/"coexisting project" special-casing from `deploy/Makefile` end-to-end (2026-08-14). This went through a few iterations the same day: first per-field `oc patch` reconciliation, then a git-tracked `oc apply` manifest (`manifests/dsc-shared-overrides.yaml`), both trying to make this project's `trustyai`/`kserve`/`mlflowoperator` desired state survive a shared `rhoai-platform` Helm release owned by the coexisting `open-claw-in-openshell` project. All of it was removed once the real workflow was clarified: `make cluster-cleanup` (full teardown) before switching which project's stack is deployed on a given cluster — not indefinite side-by-side coexistence with divergent component sets. With that workflow, every `deploy-*` target's "skip if release already exists" branch (`deploy-operators`, `deploy-database`, `deploy-mlflow`, `deploy-evalhub`, and `deploy-platform`/`deploy-platform-fresh`, the latter two now merged into one target) was also unnecessary complexity: plain `helm upgrade --install` is already idempotent, so every one of those targets now just runs it unconditionally, no "already deployed" check at all. Also simplified: `wait-evalhub-crd` no longer treats a missing CRD as an expected "TrustyAI Removed on a shared DSC" outcome to silently skip (this project's own `deploy-platform` always sets `trustyai: Managed`, so the CRD reliably appears — same plain registration-race wait as `wait-mlflow-crd`/`wait-dashboard-crd`). Coexistence-flavored comments were also cleaned up in `values.yaml` (openclaw-ui-proxy, openshell route), `scripts/openshift-openshell-register-gateway.sh`, and [ADR-0008](adr/0008-rhoai-dsc-component-selection.md) (which was additionally stale — still listed `kserve` as `Removed`). Net effect: this project's deploy scripts no longer reference or reason about `open-claw-in-openshell` (or any other coexisting project) anywhere; if you want two independent stacks live on the same cluster at once, that's back to being a manual, unsolved concern, not something this Makefile tries to paper over.



## Phase 2 - Architecture and Agent Design

- [x] Decide agent harness: OpenClaw (validated against a reference deployment)
- [x] Decide agent use case (what the agent actually does)
- [x] Create detailed architecture document with deployment topology — [AGENT-SANDBOX-AND-OPENSHELL.md](AGENT-SANDBOX-AND-OPENSHELL.md) + [demo/overall-demo-architecture.html](demo/overall-demo-architecture.html)
- [x] Define guardrails policies (self-check input/output, jailbreak) — [deploy/helm/guardrails/files/](../deploy/helm/guardrails/files/)
- [x] Design the demo narrative and attack scenarios — active script [`demo-narrative-v1.md`](demo-narrative-v1.md); EvalHub extension [`demo-narrative-v2.md`](demo-narrative-v2.md)



## Phase 3 - Implementation

- [x] Implement agent configuration with OpenClaw harness
- [x] Configure NeMo Guardrails (rails, actions, policies) — see [nemo-guardrails-installation.md](nemo-guardrails-installation.md)
- [x] Playwright guardrails E2E (`tests/guardrails-ui.spec.ts`, `make -C deploy test-guardrails`)
- [x] Configure MLflow tracing integration
- [x] Deploy and validate on RHOAI 3.x cluster
- [ ] Implement attack scenarios for the security demo — scripts + narrative in [`demo-narrative-v1.md`](demo-narrative-v1.md); validate Prueba C egress on cluster



## Phase 4 - Packaging and Polish

- [x] Scaffold Helm charts for one-command deployment — RHOAI + OpenShell: `[deploy/helm/openshell/](../deploy/helm/openshell/)` + `make -C deploy deploy-openshell`
- [x] Refactor OpenShell wrapper chart (`0.3.0`): absorb namespace + SCC RoleBinding into Helm; Agent Sandbox via OLM only (OSC 1.13); retire kustomize + SCC script + raw `v0.5.1` manifest — see [ADR-0003](adr/0003-openshell-deployment-on-openshift.md)
- [x] Write step-by-step demo script with timing marks (~9–10 min live) — [`demo-script.md`](demo-script.md) (English); narrative [`demo-narrative-v1.md`](demo-narrative-v1.md) (Spanish)
- [x] Create health-check script (`tests/health-check.sh`)
- [x] Create warm-up script — skill `demo-warmup`, script `scripts/demo-warmup.sh`
- [ ] DemoJam Record fallback video
- [ ] DemoJam Build presentation slides (5-8 min theory)
- [x] Rename github proyect.
- [ ] Review proxy connectivity resiliency


## Phase 5 — Platform Enhancements (Q3/Q4 2026 Roadmap)

> Post-demo evolution. Incorporates new Red Hat platform capabilities identified
> in the Q3 2026 planning meeting and product briefings for OpenShift and RHOAI.
> These items are **not blockers** for the current demo — they represent the next
> evolution of the platform stack.

### Phase 5.1: MCP Gateway Integration (P1)

> Action item: David Severiano

**Priority**: 🔥 High — directly extends the demo security narrative.
**Maturity**: Technology Preview (Red Hat Connectivity Link 1.4, MCP Gateway 0.7.0).

Integrate [MCP Gateway](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.4/html/mcp_gateway/mcp-gateway-introduction)
to federate and govern agent tool access through a single managed endpoint.

Capabilities:
- **Aggregation**: single gateway endpoint federates tools from multiple MCP servers
  (`MCPServerRegistration` CR with prefix-based tool namespacing)
- **Authentication**: OAuth2/JWT via Kuadrant `AuthPolicy` (Keycloak, any OIDC provider);
  discovery at `/.well-known/oauth-protected-resource`
- **Authorization**: per-tool access control with CEL or OPA rules on `AuthPolicy`
  (tool-level RBAC via identity token claims)
- **Rate limiting**: per-user/per-agent limits via `RateLimitPolicy` on Gateway/HTTPRoute

Architecture: Envoy proxy + Gateway API + Istio + Connectivity Link policies.

Tasks:
- [ ] Research: evaluate MCP Gateway on OCP 4.20+ with Connectivity Link 1.4
- [ ] Deploy MCP Gateway on demo cluster (Helm + OLM)
- [ ] Register at least one MCP server behind the gateway
- [ ] Configure `AuthPolicy` with Keycloak for agent authentication
- [ ] Configure `RateLimitPolicy` for agent tool-call limits
- [ ] Wire agent (OpenClaw in sandbox) to call tools via MCP Gateway endpoint
- [ ] Demo scenario: show agent tool call governed by auth + rate limiting
- [ ] Document integration in `docs/` and create ADR

References:
- [Blog: Control your AI agent traffic at scale](https://www.redhat.com/en/blog/control-your-ai-agent-traffic-scale-model-context-protocol-gateway-red-hat-openshift-now-technology-preview)
- [Install guide](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.4/html/install_the_mcp_gateway/mcp-gateway-install)
- [Auth](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.4/html/registering_mcp_servers_and_creating_policies/mcp-gateway-authentication)
- [Authorization](https://docs.redhat.com/en/documentation/red_hat_connectivity_link/1.4/html/registering_mcp_servers_and_creating_policies/mcp-gateway-authorization)

### Phase 5.2: SPIFFE/SPIRE + OpenShell Agent Identity (P1)

> Action item: David Severiano

**Priority**: 🔥 High — extends zero-trust narrative with cryptographic agent identity.
**Maturity**: GA (Zero Trust Workload Identity Manager on OCP 4.20, v1.1) +
mergeado in OpenShell ([PR #1784](https://github.com/NVIDIA/OpenShell/pull/1784)).

Replace static credentials with SPIFFE-based dynamic identity for agents in
OpenShell sandboxes. The sandbox supervisor obtains JWT-SVIDs from SPIRE,
exchanges them for short-lived endpoint-specific OAuth tokens, and injects
bearer tokens into matching HTTP requests. The agent never sees the SVID or
the SPIFFE socket.

Current state → Target state:
- `apiKey: "unused"` + inference router → JWT-SVID → token exchange → dynamic bearer
- Manual mTLS between CLI gateway and cluster → SVID-based mTLS, SPIRE-managed trust domain
- No verifiable agent identity → SPIFFE ID: `spiffe://<domain>/openshell/sandbox/<id>`

OpenShell Helm config:
```yaml
server:
  providerTokenGrants:
    spiffe:
      enabled: true
      workloadApiSocketPath: "/spiffe-workload-api/spire-agent.sock"
```

Prerequisites on OCP:
- Zero Trust Workload Identity Manager operator (GA, OCP 4.20+)
- SPIRE server + agents (DaemonSet)
- SPIFFE CSI driver
- `ClusterSPIFFEID` CRDs for workload registration

Tasks:
- [ ] Deploy Zero Trust Workload Identity Manager on OCP 4.20+ cluster
- [ ] Configure SPIRE server, agents, and CSI driver
- [ ] Enable SPIFFE provider token grants in OpenShell Helm chart
- [ ] Create provider profile with `token_grant` metadata for inference endpoint
- [ ] Validate: sandbox agent gets endpoint-specific bearer token via SVID exchange
- [ ] Demo scenario: show agent identity is cryptographically verifiable (not static key)
- [ ] Run OpenShell's included demo: `examples/spiffe-token-grant-demo/`
- [ ] Document SPIFFE integration in `docs/` and create ADR

References:
- [OpenShell SPIFFE docs](https://docs.nvidia.com/openshell/dev/kubernetes/access-control)
- [OCP 4.20 Zero Trust Workload Identity Manager](https://docs.redhat.com/en/documentation/openshift_container_platform/4.20/html/security_and_compliance/zero-trust-workload-identity-manager)
- [Blog: Zero Trust WIM v1.1 GA](https://www.redhat.com/en/blog/zero-trust-workload-identity-manager-11-generally-available-red-hat-openshift)
- [RHOAI 3.5 blog: SPIFFE direction](https://www.redhat.com/en/blog/beyond-container-boundaries-kernel-level-agent-security-red-hat-openshift-ai-35)

### Phase 5.3: OpenShell A2A Transport + OpenClaw A2A Channel (P2)

> Action item: David Severiano / Carlos Cornejo

**Priority**: 🟡 Medium — enables governed multi-agent narrative.
**Maturity**: OpenShell proxy supports A2A transport; OpenClaw A2A channel is GA
([docs](https://docs.openclaw.ai/channels/a2a)).

Enable agent-to-agent communication using the A2A protocol. OpenShell's proxy
handles A2A JSON-RPC transport while AgentCard discovery happens at the
catalog/gateway level. OpenClaw publishes an AgentCard automatically and can
delegate tasks to peer agents.

OpenClaw A2A capabilities:
- Publishes AgentCard at `/.well-known/agent-card.json` (auto-generated)
- Inbound: authenticated JSON-RPC tasks via A2A 1.0 binding
- Outbound: configurable peers with `channels.a2a.peers`
- Configurable: `exposeAgents`, `rateLimitPerMinute`, `advertisedUrl`
- Current limitations: no streaming, push notifications, or task cancellation

Tasks:
- [ ] Enable A2A channel in OpenClaw configuration
- [ ] Configure AgentCard exposure (`exposeAgents`) for the demo agent
- [ ] Validate: A2A AgentCard published and reachable from outside the sandbox
- [ ] Evaluate: OpenShell proxy A2A transport + SPIFFE identity injection
- [ ] PoC: second agent discovers and delegates to the demo agent via A2A
- [ ] Document A2A integration and update architecture diagram

References:
- [Red Hat blog: Building governed multi-agent networks](https://www.redhat.com/en/blog/why-single-ai-agents-fail-scale-building-governed-multi-agent-networks)
- [OpenClaw A2A channel docs](https://docs.openclaw.ai/channels/a2a)
- [A2A protocol: Agent discovery](https://github.com/google/A2A/blob/main/docs/topics/agent-discovery.md)


## Deferred



### Progressive network-policy unlock for the Security Attack demo

> **Active demo narrative.** The live script ([`demo-narrative-v1.md`](demo-narrative-v1.md)) starts with MaaS + MLflow already reachable and **default-deny egress** (`default.yaml`). Test C runs blocked first; Change 1 applies selective google.com allowlist via `demo-allow-google-egress.sh`.

Found while comparing this project against a related OpenShell/OpenCode reference demo
([r3v5/agent-ops,](https://github.com/r3v5/agent-ops/tree/opencode-in-openshell-with-mlflow-on-openshift-demo/demos/opencode-vertex-tracing) `opencode-vertex-tracing`).
That demo's narrative starts from a fully default-deny sandbox, shows a tool call fail live,
then unlocks endpoints one at a time with `openshell policy update <sandbox> --add-endpoint <host>:443 --binary <path> --wait` — a strong "zero-trust, progressively opened" visual for a
live audience.

Active v1 demo now aligns with that unlock direction for egress:

- [x] Demo-initial policy with default deny — [`config/openshell/default.yaml`](../config/openshell/default.yaml)
- [x] Live allowlist script — [`scripts/demo-allow-google-egress.sh`](../scripts/demo-allow-google-egress.sh) applies [`config/openshell/google-egress.yaml`](../config/openshell/google-egress.yaml)
- [x] Narrative + timed script — [`demo-narrative-v1.md`](demo-narrative-v1.md), [`demo-script.md`](demo-script.md)
- [x] Keep `config/openshell/default.yaml` as CI / `validate-security` baseline (unchanged)
- [x] Optional: document per-endpoint `openshell policy update --add-endpoint` as an alternate Change 1 presentation



