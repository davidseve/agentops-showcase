#!/usr/bin/env bash
# launch-openclaw.sh — Launch OpenClaw gateway inside an OpenShell sandbox.
#
# This is the one imperative step that cannot be expressed as a Helm chart
# because it requires runtime interaction with the sandbox process namespace.
#
# Automates (idempotent):
#   - CLI gateway select / register+mTLS if missing (openshift-openshell-register-gateway.sh)
#   - Sandbox create if missing (openshell sandbox create)
#
# Key design decisions (from the reference project):
#   - mlflow-openclaw plugin is the sole trace source (not diagnostics-otel)
#   - Plugin requires patching for OpenClaw 2026.7.1 compat (patch-mlflow-plugin.py)
#   - Extensions must be root-owned (OpenClaw "suspicious ownership" check)
#   - Config file must be owned by sandbox UID (OpenClaw reads as sandbox user)
#   - Combined CA bundle (OpenShell proxy + RHOAI service-ca) for TLS trust
#   - OTEL exporters disabled (OTEL_*_EXPORTER=none) — mlflow-openclaw handles traces
#
# Usage: ./scripts/launch-openclaw.sh
# Prereqs: OpenShell deployed (make -C deploy deploy-openshell), secrets/secrets.env
#   (MAAS_API_KEY, OPENCLAW_GATEWAY_PASSWORD; INFERENCE_MODEL, MAAS_BASE_URL, INFERENCE_BACKEND, NEMO_*)
# Env overrides:
#   OPENCLAW_PIN              npm package pin (default 2026.10.8)
#   OPENCLAW_SANDBOX_IMAGE    OCI image for sandbox create (Node >=24.22.1 for 2026.10.8)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
NAMESPACE="${NAMESPACE:-openshell}"
SANDBOX_NAME="${SANDBOX_NAME:-openclaw-gw}"
GATEWAY_NAME="${GATEWAY_NAME:-ocp}"
OPENSHELL_RELEASE_NAME="${OPENSHELL_RELEASE_NAME:-openshell}"
SANDBOX_SA_NAME="${SANDBOX_SA_NAME:-${OPENSHELL_RELEASE_NAME}-sandbox}"
APPS_DOMAIN="${APPS_DOMAIN:-}"
RHOAI_NS="${RHOAI_NS:-redhat-ods-applications}"
# OpenShell Community catalog retired — explicit Node image (ADR-0006).
# openclaw@2026.10.8 engines require Node >=24.22.1; current ubi9/nodejs-24:latest
# is still 24.21.0, so default to the Node.js official 24.22 bookworm image.
OPENCLAW_SANDBOX_IMAGE="${OPENCLAW_SANDBOX_IMAGE:-docker.io/library/node:24.22-bookworm}"
POLICY_FILE="${POLICY_FILE:-${PROJECT_DIR}/config/openshell/default.yaml}"
if [[ "$POLICY_FILE" != /* ]]; then
  POLICY_FILE="${PROJECT_DIR}/${POLICY_FILE#./}"
fi

info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*"; }
error() { echo "[ERROR] $*" >&2; }
pass()  { echo "[PASS]  $*"; }
step()  { echo ""; echo "── $* ──"; }

# Load secrets + inference config (single source: secrets/secrets.env)
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
load_inference_config || exit 1

command -v openshell >/dev/null 2>&1 || { error "openshell CLI is required"; exit 1; }
command -v oc >/dev/null 2>&1 || { error "oc is required"; exit 1; }

if [[ -z "$APPS_DOMAIN" ]]; then
  APPS_DOMAIN=$(oc get ingress.config.openshift.io cluster -o jsonpath='{.spec.domain}')
fi
# OpenShell 0.1.6+ exposes services as {workspace}--{sandbox}--{service}.{domain}
UI_HOST="${OPENSHELL_WORKSPACE:-default}--${SANDBOX_NAME}--openclaw-ui.${APPS_DOMAIN}"
MLFLOW_TOKEN_SECRET="${SANDBOX_SA_NAME}-mlflow-token"

# ─── Ensure local CLI points at this project's gateway ────────────────────────
step "Ensuring OpenShell CLI gateway '${GATEWAY_NAME}'"
NAMESPACE="${NAMESPACE}" GATEWAY_NAME="${GATEWAY_NAME}" \
  "${SCRIPT_DIR}/openshift-openshell-register-gateway.sh"

# ─── MLflow wiring ────────────────────────────────────────────────────────────
step "Reading MLflow wiring"
MLFLOW_TOKEN="${MLFLOW_TOKEN:-}"
if [[ -z "$MLFLOW_TOKEN" ]]; then
  MLFLOW_TOKEN=$(oc -n "$NAMESPACE" get secret "${MLFLOW_TOKEN_SECRET}" \
    -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || true)
fi
if [[ -z "$MLFLOW_TOKEN" ]]; then
  error "MLflow token not available. Run: make -C deploy deploy-openshell"
  exit 1
fi
info "MLflow SA token read from Secret"

# OpenShell 0.1.6+ sandbox DNS does not resolve short ".svc" names (ENOTFOUND);
# use cluster FQDN (validated 2026-11-02 with mlflow-openclaw export).
MLFLOW_SVC_URL="https://mlflow.${RHOAI_NS}.svc.cluster.local:8443/mlflow"
MLFLOW_EXPERIMENT_NAME="${MLFLOW_EXPERIMENT_NAME:-openclaw-tracing}"
# Placeholder until sandbox exists and we can resolve by name (per-workspace ids differ).
MLFLOW_EXPERIMENT_ID="${MLFLOW_EXPERIMENT_ID:-__RESOLVE__}"
info "MLflow tracking URI: ${MLFLOW_SVC_URL} (experiment id resolved after sandbox is ready)"

# ─── OpenShell 0.1.6+ provider profiles (replaces inference.local) ────────────
# shellcheck source=openshell-inference.sh
source "${SCRIPT_DIR}/openshell-inference.sh"
ensure_openshell_inference_providers || exit 1

ACTIVE_PROVIDER="$(active_inference_provider "$INFERENCE_BACKEND")"
ACTIVE_BASE_URL="$(active_inference_base_url "$INFERENCE_BACKEND")"

# ─── Render config ────────────────────────────────────────────────────────────
# OpenShell 0.1.6 removed inference.local. OpenClaw calls the native MaaS/NeMo
# baseUrl; the attached provider injects OPENAI_API_KEY at the authorized host.
step "Rendering openclaw.json"
CONFIG_RENDERED="${PROJECT_DIR}/.rendered/openclaw.json"
mkdir -p "$(dirname "$CONFIG_RENDERED")"
sed -e "s|__APPS_DOMAIN__|${APPS_DOMAIN}|g" \
    -e "s|__UI_HOST__|${UI_HOST}|g" \
    -e "s|__MLFLOW_EXPERIMENT_ID__|${MLFLOW_EXPERIMENT_ID}|g" \
    -e "s|__OPENCLAW_GATEWAY_PASSWORD__|${OPENCLAW_GATEWAY_PASSWORD}|g" \
    -e "s|__INFERENCE_BASE_URL__|${ACTIVE_BASE_URL}|g" \
    -e "s|__INFERENCE_MODEL__|${INFERENCE_MODEL}|g" \
    "${PROJECT_DIR}/config/openclaw.json.tpl" > "$CONFIG_RENDERED"
pass "Rendered config (baseUrl=${ACTIVE_BASE_URL}, model=${INFERENCE_MODEL}, experiment=${MLFLOW_EXPERIMENT_ID})"

# ─── Create sandbox if missing ────────────────────────────────────────────────
# openshell sandbox exec -n uses the logical sandbox name; oc uses the K8s pod
# name (`{workspace}--{sandbox}` on OpenShell 0.1.6+).
step "Ensuring sandbox '${SANDBOX_NAME}'"
if openshell sandbox list 2>/dev/null | awk -v n="$SANDBOX_NAME" 'index($0, n) { found=1 } END { exit !found }'; then
  info "Sandbox '$SANDBOX_NAME' already exists"
  attach_openshell_inference_backend "$INFERENCE_BACKEND" || exit 1
else
  [[ -f "$POLICY_FILE" ]] || { error "Policy file not found: $POLICY_FILE"; exit 1; }
  info "Creating sandbox (policy=$(basename "$POLICY_FILE"), provider=${ACTIVE_PROVIDER})..."
  # NOTE: no --upload here. config/openshell/default.yaml lists /sandbox
  # itself under filesystem_policy.read_only (only /sandbox/workspace is
  # read_write), so `--upload ...:/sandbox/.openclaw/config.json` is DOA —
  # the CLI's tar-over-ssh extraction always fails with "Permission denied"
  # under this policy, every single run (confirmed live 2026-08-14, and in
  # every prior launch log back to 2026-08-10). It's cosmetic-only: Step 3
  # below (`oc cp` to /sandbox/workspace/.openclaw/openclaw.json, which IS
  # writable) is the real and only config path OpenClaw reads (HOME is set
  # to /sandbox/workspace for the gateway process). Sandbox creation still
  # succeeds fine without it — dropping the flag just removes a scary but
  # meaningless red error from every deploy log.
  info "Sandbox image: ${OPENCLAW_SANDBOX_IMAGE}"
  openshell sandbox create \
    --from "$OPENCLAW_SANDBOX_IMAGE" \
    --name "$SANDBOX_NAME" \
    --policy "$POLICY_FILE" \
    --provider "$ACTIVE_PROVIDER" \
    --no-tty &
  CREATE_PID=$!

  info "Waiting for sandbox to be ready..."
  retries=0
  while [[ $retries -lt 120 ]]; do
    # Match name + Ready on the same list line (ANSI-safe; avoid bare
    # "${NAME}.*Ready" which is wrong if NAME is empty / multiline).
    if openshell sandbox list 2>/dev/null | awk -v n="$SANDBOX_NAME" '
        index($0, n) && /Ready/ { found=1 }
        END { exit !found }
      '; then
      info "Sandbox is Ready"
      break
    fi
    # Fallback: pod exists and Ready even if list formatting differs
    if pod="$(resolve_sandbox_pod "$NAMESPACE" "$SANDBOX_NAME" 2>/dev/null)"; then
      if oc -n "$NAMESPACE" get pod "$pod" -o jsonpath='{.status.phase}' 2>/dev/null | grep -q Running; then
        ready=$(oc -n "$NAMESPACE" get pod "$pod" -o jsonpath='{.status.containerStatuses[?(@.name=="agent")].ready}' 2>/dev/null || true)
        if [[ "$ready" == "true" ]]; then
          info "Sandbox pod Running/Ready ($pod)"
          break
        fi
      fi
    fi
    sleep 5
    retries=$((retries + 1))
  done
  kill "$CREATE_PID" 2>/dev/null || true
  wait "$CREATE_PID" 2>/dev/null || true

  if [[ $retries -ge 120 ]]; then
    error "Sandbox did not become ready within 10 minutes"
    exit 1
  fi
  pass "Sandbox created"
fi

SANDBOX_POD="$(resolve_sandbox_pod "$NAMESPACE" "$SANDBOX_NAME")" || {
  error "Sandbox pod for '${SANDBOX_NAME}' not found (expected default--${SANDBOX_NAME} or ${SANDBOX_NAME})"
  exit 1
}
info "Sandbox pod: $SANDBOX_POD (logical name: ${SANDBOX_NAME})"

# Detect sandbox UID (OpenShift assigns arbitrary UIDs). Note: `oc exec`
# without an explicit user runs as the container's default user (root in
# the "agent" container), NOT the "sandbox" user the actual OpenClaw
# process runs as (via `openshell sandbox exec`) — so `id -u` alone would
# wrongly report 0. Query the named "sandbox" user explicitly instead.
# Prefer the named sandbox account when present; OpenShell 0.1.6/UBI often runs
# as the arbitrary OpenShift UID with no 'sandbox' entry — fall back to id -u.
SANDBOX_UID=$(oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- id -u sandbox 2>/dev/null \
  || oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- id -u 2>/dev/null \
  || echo "1000780000")
SANDBOX_GID=$(oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- id -g sandbox 2>/dev/null \
  || oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- id -g 2>/dev/null \
  || echo "1000780000")
info "Sandbox UID:GID = ${SANDBOX_UID}:${SANDBOX_GID}"

# OpenShell 0.1.6 mounts the workspace PVC at /sandbox without creating
# /sandbox/workspace. Policy read_write lists that path — create it before
# npm/config/gateway steps (oc exec as container root bypasses Landlock).
step "Ensuring /sandbox/workspace on sandbox volume"
oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- bash -c "
  mkdir -p /sandbox/workspace
  chown ${SANDBOX_UID}:${SANDBOX_GID} /sandbox/workspace
  chmod 775 /sandbox/workspace
"
pass "/sandbox/workspace ready"

# ─── Ensure MLflow experiment id (per-workspace on shared MLflow) ─────────────
if [[ "$MLFLOW_EXPERIMENT_ID" == "__RESOLVE__" ]]; then
  step "Ensuring MLflow experiment '${MLFLOW_EXPERIMENT_NAME}' in workspace ${NAMESPACE}"
  MLFLOW_WORKSPACE="$NAMESPACE"
  if ! ensure_mlflow_experiment; then
    error "Could not get or create MLflow experiment '${MLFLOW_EXPERIMENT_NAME}'"
    error "Run: make -C deploy deploy-mlflow-openclaw-integration"
    exit 1
  fi
  pass "MLflow experiment ${MLFLOW_EXPERIMENT_NAME} → id=${MLFLOW_EXPERIMENT_ID}"
fi
# Re-render so experimentId is concrete before upload.
sed -e "s|__APPS_DOMAIN__|${APPS_DOMAIN}|g" \
    -e "s|__UI_HOST__|${UI_HOST}|g" \
    -e "s|__MLFLOW_EXPERIMENT_ID__|${MLFLOW_EXPERIMENT_ID}|g" \
    -e "s|__OPENCLAW_GATEWAY_PASSWORD__|${OPENCLAW_GATEWAY_PASSWORD}|g" \
    -e "s|__INFERENCE_BASE_URL__|${ACTIVE_BASE_URL}|g" \
    -e "s|__INFERENCE_MODEL__|${INFERENCE_MODEL}|g" \
    "${PROJECT_DIR}/config/openclaw.json.tpl" > "$CONFIG_RENDERED"

# ─── Step 1: Kill stale gateway processes ─────────────────────────────────────
# MUST kill via `openshell sandbox exec`, NOT `oc exec -c agent` — the gateway
# is started with `openshell sandbox exec` (Step 9), which runs in a
# different PID namespace than plain `oc exec`. Killing via `oc exec` makes
# `pgrep -f "openclaw|node"` find nothing there, so the kill silently no-ops
# while the real gateway process keeps running untouched — every subsequent
# "restart" then just starts a second gateway on top of the first (or fails
# to bind :18789), still serving whatever stale config/env it started with.
# Verify the process list is empty afterwards — don't trust exit code alone.
step "Cleaning stale gateway processes"
# Match argv as pgrep -f sees it (no PID prefix). After start, the process often
# rewrites to bare "openclaw" — the old " openclaw$" pattern never matched that,
# so kill no-op'd and every relaunch left the stale gateway (wrong password) up.
OPENCLAW_PGREP='openclaw gateway|^openclaw$|/openclaw|node.*openclaw'
kill_stale_openclaw_gateway() {
  openshell sandbox exec -n "$SANDBOX_NAME" --no-tty --timeout 15 -- bash -c '
    for p in $(pgrep -f "'"${OPENCLAW_PGREP}"'" 2>/dev/null); do
      kill -9 "$p" 2>/dev/null
    done
    sleep 2
    rm -f /sandbox/workspace/.openclaw/state/*.lock /tmp/openclaw*/*.lock 2>/dev/null
    pgrep -af "'"${OPENCLAW_PGREP}"'" 2>/dev/null
    true
  ' 2>&1
  return 0
}
STALE_CHECK="$(kill_stale_openclaw_gateway)"
if echo "$STALE_CHECK" | grep -qE "openclaw"; then
  warn "Stale gateway process(es) survived first kill attempt — retrying:"
  echo "$STALE_CHECK" | while IFS= read -r line; do info "  $line"; done
  STALE_CHECK="$(kill_stale_openclaw_gateway)"
fi
if echo "$STALE_CHECK" | grep -qE "openclaw"; then
  error "Could not kill stale OpenClaw gateway process(es) after 2 attempts — refusing to start a second gateway on top of a live one:"
  echo "$STALE_CHECK" | while IFS= read -r line; do error "  $line"; done
  error "Fix: openshell sandbox connect ${SANDBOX_POD}, then manually 'kill -9 <pid>' for each, then re-run this script."
  exit 1
fi
info "Confirmed no stale gateway processes remain"
# Our template is the single source of truth (declarative, GitOps-style) —
# stale openclaw.json.bak* files from prior runs have no `meta.lastTouchedVersion`
# match with our fresh upload, which trips OpenClaw's "missing-meta-vs-last-good"
# anomaly detector and can make it silently *restore config from an old backup*
# instead of using what we just uploaded (bit us with a backup carrying a
# stale `auth.mode: token` + `bind: auto`, from an env var we no longer pass).
oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- bash -c \
  'rm -f /sandbox/workspace/.openclaw/openclaw.json.bak*' 2>/dev/null || true
pass "Stale processes cleaned"

# ─── Step 2: Install OpenClaw (pinned — ADR-0006) ────────────────────────────
# Pin deliberately (ADR-0006). openclaw@2026.10.8 engines: >=24.22.1 <25 || >=26.12.1.
# Fail fast if the sandbox image is too old instead of installing a package that refuses to run.
OPENCLAW_PIN="${OPENCLAW_PIN:-2026.10.8}"
OPENCLAW_MIN_NODE_MAJOR=24
OPENCLAW_MIN_NODE_MINOR=22
step "Checking Node runtime for OpenClaw ${OPENCLAW_PIN}"
NODE_VERSION_RAW=$(oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- node --version 2>/dev/null | head -1 || true)
NODE_VERSION_RAW="${NODE_VERSION_RAW#v}"
NODE_MAJOR="${NODE_VERSION_RAW%%.*}"
NODE_REST="${NODE_VERSION_RAW#*.}"
NODE_MINOR="${NODE_REST%%.*}"
if [[ -z "$NODE_MAJOR" || -z "$NODE_MINOR" ]]; then
  error "Could not read node --version inside sandbox (got: '${NODE_VERSION_RAW:-empty}')."
  error "Sandbox image must include Node ${OPENCLAW_MIN_NODE_MAJOR}.${OPENCLAW_MIN_NODE_MINOR}+ (override OPENCLAW_SANDBOX_IMAGE)."
  exit 1
fi
if (( NODE_MAJOR < OPENCLAW_MIN_NODE_MAJOR )) || \
   { (( NODE_MAJOR == OPENCLAW_MIN_NODE_MAJOR )) && (( NODE_MINOR < OPENCLAW_MIN_NODE_MINOR )); }; then
  error "Sandbox Node v${NODE_VERSION_RAW} is below OpenClaw ${OPENCLAW_PIN} requirement (need >= ${OPENCLAW_MIN_NODE_MAJOR}.${OPENCLAW_MIN_NODE_MINOR}.0)."
  error "Recreate the sandbox with OPENCLAW_SANDBOX_IMAGE pointing at Node >=24.22.1 (default: docker.io/library/node:24.22-bookworm)."
  exit 1
fi
# Patch-level floor for 24.x (engines require 24.22.1, not just 24.22.0).
NODE_PATCH="${NODE_REST#*.}"; NODE_PATCH="${NODE_PATCH%%[^0-9]*}"
if (( NODE_MAJOR == 24 && NODE_MINOR == 22 && ${NODE_PATCH:-0} < 1 )); then
  error "Sandbox Node v${NODE_VERSION_RAW} is below OpenClaw ${OPENCLAW_PIN} requirement (need >= 24.22.1)."
  exit 1
fi
pass "Node v${NODE_VERSION_RAW} OK for OpenClaw ${OPENCLAW_PIN}"

step "Ensuring OpenClaw ${OPENCLAW_PIN} is installed"
# Sandbox egress policy blocks registry.npmjs.org, and the UBI npm prefix under
# /opt/app-root is not writable by the arbitrary OpenShift UID. Fetch the
# package in an ephemeral (non-sandboxed) pod, then extract into the sandbox
# workspace prefix.
NPM_PREFIX="/sandbox/workspace/.npm-global"
CURRENT_VERSION=$(oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- \
  bash -c "export PATH=${NPM_PREFIX}/bin:\$PATH; openclaw --version 2>/dev/null" | head -1 || true)
if [[ "$CURRENT_VERSION" != *"$OPENCLAW_PIN"* ]]; then
  info "Fetching openclaw@${OPENCLAW_PIN} via ephemeral npm pod (sandbox egress blocks npmjs)..."
  FETCH_POD="openclaw-npm-fetch-${RANDOM}"
  BUNDLE="${PROJECT_DIR}/.rendered/openclaw-${OPENCLAW_PIN}.tgz"
  mkdir -p "$(dirname "$BUNDLE")"
  oc -n "$NAMESPACE" delete pod "$FETCH_POD" --ignore-not-found --wait=true &>/dev/null || true
  cat <<EOF | oc -n "$NAMESPACE" apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${FETCH_POD}
  labels:
    app: openclaw-npm-fetch
spec:
  restartPolicy: Never
  containers:
    - name: fetch
      image: ${OPENCLAW_SANDBOX_IMAGE}
      command: ["bash", "-lc"]
      args:
        - |
          set -euo pipefail
          export HOME=/tmp
          mkdir -p /tmp/npm-global /tmp/.npm
          NPM_CONFIG_PREFIX=/tmp/npm-global NPM_CONFIG_CACHE=/tmp/.npm \
            npm install -g "openclaw@${OPENCLAW_PIN}"
          tar -C /tmp/npm-global -czf /tmp/openclaw-npm.tgz .
          echo FETCH_OK
          # Stay Running so `oc cp` can read the tarball (Completed pods reject exec/cp).
          sleep 3600
      securityContext:
        allowPrivilegeEscalation: false
        capabilities: { drop: ["ALL"] }
        runAsNonRoot: true
        seccompProfile: { type: RuntimeDefault }
EOF
  i=0
  fetch_ok=false
  while [[ $i -lt 180 ]]; do
    phase="$(oc -n "$NAMESPACE" get pod "$FETCH_POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    if [[ "$phase" == "Failed" ]]; then
      break
    fi
    if oc -n "$NAMESPACE" logs "$FETCH_POD" -c fetch 2>/dev/null | grep -q 'FETCH_OK'; then
      fetch_ok=true
      break
    fi
    i=$((i + 1))
    sleep 2
  done
  if [[ "$fetch_ok" != "true" ]]; then
    error "npm fetch pod ${FETCH_POD} failed:"
    oc -n "$NAMESPACE" logs "$FETCH_POD" -c fetch 2>&1 | tail -40 || true
    oc -n "$NAMESPACE" delete pod "$FETCH_POD" --ignore-not-found --wait=false &>/dev/null || true
    exit 1
  fi
  oc -n "$NAMESPACE" cp "${FETCH_POD}:/tmp/openclaw-npm.tgz" "$BUNDLE" -c fetch
  oc -n "$NAMESPACE" delete pod "$FETCH_POD" --ignore-not-found --wait=false &>/dev/null || true
  info "Extracting OpenClaw bundle into sandbox ${NPM_PREFIX}..."
  oc -n "$NAMESPACE" cp "$BUNDLE" "${SANDBOX_POD}:/tmp/openclaw-npm.tgz" -c agent
  oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- bash -c "
    mkdir -p ${NPM_PREFIX}
    tar -C ${NPM_PREFIX} -xzf /tmp/openclaw-npm.tgz
    chown -R ${SANDBOX_UID}:${SANDBOX_GID} ${NPM_PREFIX}
    rm -f /tmp/openclaw-npm.tgz
  "
fi
OPENCLAW_VERSION=$(oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- \
  bash -c "export PATH=${NPM_PREFIX}/bin:\$PATH; openclaw --version" 2>&1 | head -1)
pass "OpenClaw version: $OPENCLAW_VERSION"

# ─── Step 3: Upload config ────────────────────────────────────────────────────
step "Uploading rendered config to sandbox"
oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- mkdir -p /sandbox/workspace/.openclaw
oc -n "$NAMESPACE" cp "$CONFIG_RENDERED" "${SANDBOX_POD}:/sandbox/workspace/.openclaw/openclaw.json" -c agent
oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- \
  chown "${SANDBOX_UID}:${SANDBOX_GID}" /sandbox/workspace/.openclaw/openclaw.json
# OpenClaw 2026.10.x is strict about retired keys — normalize in-place if needed.
openshell sandbox exec -n "$SANDBOX_NAME" --no-tty --timeout 90 \
  --env "HOME=/sandbox/workspace" \
  --env "PATH=/sandbox/workspace/.npm-global/bin:/usr/local/bin:/usr/bin:/bin" \
  -- bash -c 'openclaw config validate >/dev/null 2>&1 || openclaw doctor --fix' \
  >/dev/null 2>&1 || true
pass "Config uploaded (owned by sandbox UID ${SANDBOX_UID})"

# ─── Step 3b: Upload workspace bootstrap (demo AGENTS.md / SOUL.md) ───────────
# OpenClaw injects workspace bootstrap files into every session system prompt.
# Default bootstrap refuses sensitive probes; demo workspace overrides that so
# Landlock/egress/guardrails — not LLM refusal — are what the audience sees.
WORKSPACE_SRC="${PROJECT_DIR}/agent/workspace"
step "Uploading workspace bootstrap files"
if [[ -d "$WORKSPACE_SRC" ]]; then
  for ws_file in AGENTS.md SOUL.md IDENTITY.md; do
    if [[ -f "${WORKSPACE_SRC}/${ws_file}" ]]; then
      oc -n "$NAMESPACE" cp "${WORKSPACE_SRC}/${ws_file}" \
        "${SANDBOX_POD}:/sandbox/workspace/${ws_file}" -c agent
      oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- \
        chown "${SANDBOX_UID}:${SANDBOX_GID}" "/sandbox/workspace/${ws_file}"
      info "  uploaded ${ws_file}"
    fi
  done
  pass "Workspace bootstrap ready (skipBootstrap=true in openclaw.json)"
else
  warn "agent/workspace not found — OpenClaw may use default bootstrap templates"
fi

# ─── Step 4: Install mlflow-openclaw plugin ───────────────────────────────────
# This plugin hooks into OpenClaw's agent lifecycle events and creates MLflow
# traces with full Request/Response content (unlike diagnostics-otel which only
# sends generic OTEL spans).
step "Installing mlflow-openclaw plugin"
PLUGIN_DIR="/sandbox/workspace/.openclaw/extensions/mlflow-openclaw"
PLUGIN_PIN="${MLFLOW_OPENCLAW_PIN:-0.2.0-rc.0}"
PLUGIN_INSTALLED=$(oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- \
  test -f "${PLUGIN_DIR}/node_modules/@mlflow/mlflow-openclaw/openclaw.plugin.json" 2>/dev/null && echo "YES" || echo "NO")
if [[ "$PLUGIN_INSTALLED" == "YES" ]]; then
  info "mlflow-openclaw plugin already installed"
else
  info "Fetching @mlflow/mlflow-openclaw@${PLUGIN_PIN} via ephemeral npm pod..."
  FETCH_POD="mlflow-plugin-fetch-${RANDOM}"
  PLUGIN_BUNDLE="${PROJECT_DIR}/.rendered/mlflow-openclaw-${PLUGIN_PIN}.tgz"
  mkdir -p "$(dirname "$PLUGIN_BUNDLE")"
  oc -n "$NAMESPACE" delete pod "$FETCH_POD" --ignore-not-found --wait=true &>/dev/null || true
  cat <<EOF | oc -n "$NAMESPACE" apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: ${FETCH_POD}
  labels:
    app: mlflow-plugin-fetch
spec:
  restartPolicy: Never
  containers:
    - name: fetch
      image: ${OPENCLAW_SANDBOX_IMAGE}
      command: ["bash", "-lc"]
      args:
        - |
          set -euo pipefail
          export HOME=/tmp
          mkdir -p /tmp/plugin /tmp/.npm
          cd /tmp/plugin
          npm init -y >/dev/null
          NPM_CONFIG_CACHE=/tmp/.npm npm install "@mlflow/mlflow-openclaw@${PLUGIN_PIN}"
          tar -czf /tmp/mlflow-plugin.tgz .
          echo FETCH_OK
          sleep 3600
      securityContext:
        allowPrivilegeEscalation: false
        capabilities: { drop: ["ALL"] }
        runAsNonRoot: true
        seccompProfile: { type: RuntimeDefault }
EOF
  i=0
  fetch_ok=false
  while [[ $i -lt 180 ]]; do
    phase="$(oc -n "$NAMESPACE" get pod "$FETCH_POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)"
    [[ "$phase" == "Failed" ]] && break
    if oc -n "$NAMESPACE" logs "$FETCH_POD" -c fetch 2>/dev/null | grep -q 'FETCH_OK'; then
      fetch_ok=true
      break
    fi
    i=$((i + 1))
    sleep 2
  done
  if [[ "$fetch_ok" != "true" ]]; then
    error "mlflow plugin fetch pod ${FETCH_POD} failed:"
    oc -n "$NAMESPACE" logs "$FETCH_POD" -c fetch 2>&1 | tail -40 || true
    oc -n "$NAMESPACE" delete pod "$FETCH_POD" --ignore-not-found --wait=false &>/dev/null || true
    exit 1
  fi
  oc -n "$NAMESPACE" cp "${FETCH_POD}:/tmp/mlflow-plugin.tgz" "$PLUGIN_BUNDLE" -c fetch
  oc -n "$NAMESPACE" delete pod "$FETCH_POD" --ignore-not-found --wait=false &>/dev/null || true
  oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- mkdir -p "${PLUGIN_DIR}"
  oc -n "$NAMESPACE" cp "$PLUGIN_BUNDLE" "${SANDBOX_POD}:/tmp/mlflow-plugin.tgz" -c agent
  oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- bash -c "
    set -euo pipefail
    mkdir -p ${PLUGIN_DIR}
    tar -C ${PLUGIN_DIR} -xzf /tmp/mlflow-plugin.tgz
    cp ${PLUGIN_DIR}/node_modules/@mlflow/mlflow-openclaw/openclaw.plugin.json ${PLUGIN_DIR}/
    # OpenClaw 2026.10.x copies extensions into plugin-captures and resolves bare
    # package imports to index.js. @mlflow/mlflow-openclaw ships only index.ts
    # (no main/exports) → load fails with "Cannot find package .../index.js".
    # Relative .ts import + explicit main/exports keeps the capture loader happy.
    echo 'export { default } from \"./node_modules/@mlflow/mlflow-openclaw/index.ts\";' > ${PLUGIN_DIR}/index.ts
    python3 - <<'PY'
import json
from pathlib import Path
root = Path('${PLUGIN_DIR}')
pkg_path = root / 'package.json'
with pkg_path.open() as f:
    d = json.load(f)
d['name'] = 'mlflow-openclaw'
d['main'] = './index.ts'
d['type'] = 'module'
with pkg_path.open('w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
nested = root / 'node_modules/@mlflow/mlflow-openclaw/package.json'
with nested.open() as f:
    np = json.load(f)
np['main'] = './index.ts'
np['exports'] = {'.': './index.ts'}
with nested.open('w') as f:
    json.dump(np, f, indent=2)
    f.write('\n')
PY
    chown -R ${SANDBOX_UID}:${SANDBOX_GID} ${PLUGIN_DIR}
    rm -f /tmp/mlflow-plugin.tgz
  "
  pass "mlflow-openclaw plugin installed"
fi

# ─── Step 5: Patch plugin for OpenClaw compatibility ──────────────────────────
# @mlflow/mlflow-openclaw@0.2.0-rc.0 was built for a newer OpenClaw SDK.
# Patches: service.ts (diagnostics-otel no-op), index.ts (definePluginEntry),
# @mlflow/core auth/index.js (X-MLFLOW-WORKSPACE header backport).
step "Patching mlflow-openclaw plugin for compatibility"
oc -n "$NAMESPACE" cp "${PROJECT_DIR}/scripts/patch-mlflow-plugin.py" \
  "${SANDBOX_POD}:/tmp/patch-mlflow-plugin.py" -c agent
oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- python3 /tmp/patch-mlflow-plugin.py 2>&1 \
  | while IFS= read -r line; do info "$line"; done
oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- \
  chown -R root:root "${PLUGIN_DIR}" 2>/dev/null || true
pass "Plugin installed and patched (root-owned)"

# ─── Step 6: Stage CA bundle ──────────────────────────────────────────────────
# The mlflow-openclaw plugin needs TLS trust for RHOAI MLflow's service-ca-signed
# certificate. We combine OpenShell's proxy CA with RHOAI's service-ca.
COMBINED_CA="/sandbox/workspace/.combined-ca-bundle.pem"
step "Staging combined CA bundle for TLS trust"
oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- bash -c \
  "cat /etc/openshell-tls/openshell-ca.pem > ${COMBINED_CA} 2>/dev/null || true"
oc get configmap -n "$NAMESPACE" openshift-service-ca.crt -o jsonpath='{.data.service-ca\.crt}' 2>/dev/null \
  | oc -n "$NAMESPACE" exec -i "$SANDBOX_POD" -c agent -- bash -c "cat >> ${COMBINED_CA}"
oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- \
  chown "${SANDBOX_UID}:${SANDBOX_GID}" "${COMBINED_CA}"
pass "Combined CA bundle staged at ${COMBINED_CA}"

# Sidecar files for MLflow tracing (openclaw.json schema cannot carry workspace).
GATEWAY_ENV="/sandbox/workspace/.openclaw/gateway.env"
MLFLOW_WORKSPACE_FILE="/sandbox/workspace/.openclaw/mlflow-workspace"
step "Writing MLflow tracing sidecar files"
oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- bash -c "
  printf '%s\\n' '${NAMESPACE}' > '${MLFLOW_WORKSPACE_FILE}'
  cat > '${GATEWAY_ENV}' <<EOF
MLFLOW_TRACKING_TOKEN=${MLFLOW_TOKEN}
MLFLOW_WORKSPACE=${NAMESPACE}
NODE_EXTRA_CA_CERTS=${COMBINED_CA}
NODE_TLS_REJECT_UNAUTHORIZED=0
OTEL_TRACES_EXPORTER=none
OTEL_METRICS_EXPORTER=none
TMPDIR=/sandbox/workspace/.openclaw/tmp
SQLITE_TMPDIR=/sandbox/workspace/.openclaw/tmp
OPENCLAW_TEMP=/sandbox/workspace/.openclaw/tmp
EOF
  chown ${SANDBOX_UID}:${SANDBOX_GID} '${MLFLOW_WORKSPACE_FILE}' '${GATEWAY_ENV}'
  chmod 600 '${GATEWAY_ENV}'
"
pass "MLflow sidecar files ready (workspace=${NAMESPACE})"

# ─── Step 7: Setup workspace dirs with correct ownership ─────────────────────
step "Setting up workspace directories"
oc -n "$NAMESPACE" exec "$SANDBOX_POD" -c agent -- bash -c "
  mkdir -p /sandbox/workspace/.openclaw/tmp \
           /sandbox/workspace/.openclaw/logs/stability \
           /sandbox/workspace/.openclaw/agents/main/sessions \
           /sandbox/workspace/.openclaw/state
  chown -R ${SANDBOX_UID}:${SANDBOX_GID} /sandbox/workspace/.openclaw/tmp \
    /sandbox/workspace/.openclaw/logs \
    /sandbox/workspace/.openclaw/agents \
    /sandbox/workspace/.openclaw/state \
    /sandbox/workspace/.openclaw/openclaw.json
  # Extensions MUST remain root-owned
  chown -R root:root /sandbox/workspace/.openclaw/extensions 2>/dev/null || true
"
pass "Workspace directories ready"

# ─── Step 8: Expose service via relay ────────────────────────────────────────
step "Registering service route in OpenShell relay"
openshell service expose "$SANDBOX_NAME" 18789 openclaw-ui 2>&1 || true
pass "Service openclaw-ui exposed → https://${UI_HOST}/"

# ─── Step 9: Start gateway ────────────────────────────────────────────────────
# Provider attachment injects OPENAI_API_KEY as an opaque placeholder; the
# OpenShell proxy substitutes the real credential only for profile-authorized
# hosts. The sandbox never sees the raw MAAS_API_KEY.
step "Starting OpenClaw gateway"
# Outer --timeout must exceed cold-start sleep (~18s) + process check margin.
openshell sandbox exec -n "$SANDBOX_NAME" --no-tty --timeout 60 \
  --env "HOME=/sandbox/workspace" \
  --env "TMPDIR=/sandbox/workspace/.openclaw/tmp" \
  --env "SQLITE_TMPDIR=/sandbox/workspace/.openclaw/tmp" \
  --env "OPENCLAW_TEMP=/sandbox/workspace/.openclaw/tmp" \
  --env "PATH=/sandbox/workspace/.npm-global/bin:/usr/local/bin:/usr/bin:/bin" \
  -- bash -c "
    set -a
    # shellcheck disable=SC1091
    source '${GATEWAY_ENV}'
    set +a
    export PATH=/sandbox/workspace/.npm-global/bin:/usr/local/bin:/usr/bin:/bin
    export TMPDIR=/sandbox/workspace/.openclaw/tmp
    export SQLITE_TMPDIR=/sandbox/workspace/.openclaw/tmp
    export OPENCLAW_TEMP=/sandbox/workspace/.openclaw/tmp
    nohup openclaw gateway run > /sandbox/workspace/openclaw.log 2>&1 &
    disown
    # OpenClaw 2026.10.x cold start is ~12s before /health answers.
    sleep 18
    # Linux COMM truncates to 15 chars → openclaw-gatewa
    if grep -lrx openclaw-gatewa /proc/*/comm >/dev/null 2>&1; then
      echo OK
    else
      echo FAIL
      tail -20 /sandbox/workspace/openclaw.log
      exit 1
    fi
  "

# ─── Step 10: Verify health + plugin loaded ───────────────────────────────────
step "Verifying gateway health + session store"
openshell sandbox exec -n "$SANDBOX_NAME" --no-tty --timeout 20 \
  --env "HOME=/sandbox/workspace" \
  -- bash -c 'curl -sf http://127.0.0.1:18789/health || exit 1' && \
  pass "Gateway healthy on :18789" || \
  { error "Health check failed — check: openshell sandbox exec -n $SANDBOX_NAME -- tail -50 /sandbox/workspace/openclaw.log"; exit 1; }

# Hard fail if Control UI chat would break (SQLite/FTS) while /health is still live.
NAMESPACE="$NAMESPACE" SANDBOX_NAME="$SANDBOX_NAME" GATEWAY_NAME="$GATEWAY_NAME" \
  "${SCRIPT_DIR}/validate-openclaw-session.sh" || \
  { error "Session store check failed — Control UI chat will not work"; exit 1; }

PLUGIN_CHECK=$(openshell sandbox exec -n "$SANDBOX_NAME" --no-tty --timeout 5 \
  --env "HOME=/sandbox/workspace" \
  -- bash -c 'grep "http server listening" /sandbox/workspace/openclaw.log | tail -1' 2>/dev/null || true)
if echo "$PLUGIN_CHECK" | grep -q "mlflow-openclaw"; then
  pass "mlflow-openclaw plugin loaded"
else
  warn "mlflow-openclaw plugin may not have loaded — check gateway log"
fi

# ─── Summary ──────────────────────────────────────────────────────────────────
step "OpenClaw launch complete"
echo ""
info "Gateway UI (nginx mTLS bridge): https://${UI_HOST}/"
info "Auth: enter OPENCLAW_GATEWAY_PASSWORD (from secrets/secrets.env) in Control UI settings"
info "      or open: https://${UI_HOST}/?password=<password>"
info "Device pairing (OpenClaw 2026.10+): Control UI requires one-time approve."
info "      After opening the UI: ./scripts/openclaw-approve-pending-devices.sh"
info "      (dangerouslyDisableDeviceAuth is retired/ignored upstream)"
info "Tracing:  mlflow-openclaw → ${MLFLOW_SVC_URL} (workspace=${NAMESPACE}, experiment=${MLFLOW_EXPERIMENT_ID})"
info "Plugins:  memory-core, mlflow-openclaw"
info ""
info "Validate: make validate-openclaw validate-traces"
info "UI proxy: APPS_DOMAIN=${APPS_DOMAIN} make -C deploy deploy-openclaw-ui-proxy"
