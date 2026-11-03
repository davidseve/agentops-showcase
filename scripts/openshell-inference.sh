#!/usr/bin/env bash
# openshell-inference.sh — OpenShell 0.1.6+ provider profiles for MaaS / NeMo.
#
# OpenShell 0.1.0 removed managed inference routes (`inference.local`,
# `openshell inference set`). Workloads call native endpoints; credentials are
# injected only for hosts declared on an imported provider profile, after the
# provider is attached to the sandbox.
#
# Usage (source from launch / demo scripts after load_inference_config):
#   source scripts/openshell-inference.sh
#   ensure_openshell_inference_providers
#   attach_openshell_inference_backend direct|guardrailed
#   patch_openclaw_inference_base_url   # updates sandbox openclaw.json baseUrl/model
#   restart_openclaw_gateway_process    # kill + start gateway (sandbox exec)
#
# CLI:
#   ./scripts/openshell-inference.sh ensure
#   ./scripts/openshell-inference.sh switch direct|guardrailed
set -euo pipefail

_OPENSHELL_INFERENCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if ! declare -F load_inference_config >/dev/null 2>&1; then
  # shellcheck source=common.sh
  source "${_OPENSHELL_INFERENCE_DIR}/common.sh"
fi

PROFILE_MAAS_ID="${PROFILE_MAAS_ID:-maas-openai}"
PROFILE_NEMO_ID="${PROFILE_NEMO_ID:-nemo-guardrails-openai}"

_url_host() {
  python3 -c "import sys,urllib.parse;print(urllib.parse.urlparse(sys.argv[1]).hostname or '')" "$1"
}

_url_port() {
  python3 -c "
import sys,urllib.parse
u=urllib.parse.urlparse(sys.argv[1])
print(u.port or (443 if u.scheme=='https' else 80))
" "$1"
}

_url_scheme() {
  python3 -c "import sys,urllib.parse;print(urllib.parse.urlparse(sys.argv[1]).scheme or 'https')" "$1"
}

_write_openai_compat_profile() {
  local out="$1" id="$2" display="$3" host="$4" port="$5" require_cred="$6"
  local cred_block
  if [[ "$require_cred" == "true" ]]; then
    cred_block=$(cat <<EOF
credentials:
  - name: api_key
    description: OpenAI-compatible API key
    env_vars: [OPENAI_API_KEY]
    required: true
    auth_style: bearer
    header_name: authorization

discovery:
  credentials: [api_key]
EOF
)
  else
    # NeMo accepts requests without a real key; still declare optional env for clients.
    cred_block=$(cat <<EOF
credentials:
  - name: api_key
    description: Optional OpenAI-compatible API key (NeMo uses upstream MaaS key)
    env_vars: [OPENAI_API_KEY]
    required: false
    auth_style: bearer
    header_name: authorization

discovery:
  credentials: [api_key]
EOF
)
  fi

  cat >"$out" <<EOF
id: ${id}
display_name: ${display}
description: AgentOps demo OpenAI-compatible inference (${id})
category: inference
inference_capable: true

${cred_block}

endpoints:
  - host: ${host}
    port: ${port}
    protocol: rest
    access: read-write
    enforcement: enforce

binaries:
  - /usr/bin/node
  - /usr/bin/node.*
  - /usr/local/bin/node
EOF
}

ensure_openshell_inference_providers() {
  load_inference_config || return 1
  command -v openshell >/dev/null 2>&1 || { error "openshell CLI is required"; return 1; }

  local rendered="${PROJECT_DIR}/.rendered/openshell-profiles"
  mkdir -p "$rendered"

  local maas_host maas_port nemo_host nemo_port
  maas_host="$(_url_host "$MAAS_BASE_URL")"
  maas_port="$(_url_port "$MAAS_BASE_URL")"
  nemo_host="$(_url_host "$NEMO_GUARDRAILS_URL")"
  nemo_port="$(_url_port "$NEMO_GUARDRAILS_URL")"
  [[ -n "$maas_host" && -n "$nemo_host" ]] || {
    error "Could not parse host from MAAS_BASE_URL / NEMO_GUARDRAILS_URL"
    return 1
  }

  step "Ensuring OpenShell provider profiles (${PROFILE_MAAS_ID}, ${PROFILE_NEMO_ID})"
  _write_openai_compat_profile \
    "${rendered}/${PROFILE_MAAS_ID}.yaml" "$PROFILE_MAAS_ID" "MaaS OpenAI-compatible" \
    "$maas_host" "$maas_port" "true"
  _write_openai_compat_profile \
    "${rendered}/${PROFILE_NEMO_ID}.yaml" "$PROFILE_NEMO_ID" "NeMo Guardrails OpenAI-compatible" \
    "$nemo_host" "$nemo_port" "false"

  _ensure_profile() {
    local id="$1" file="$2"
    if openshell profile list 2>/dev/null | awk -v n="$id" 'NR>1 && $1==n { found=1 } END { exit !found }'; then
      # update requires resource_version on some builds — import is create-only.
      info "Profile '${id}' already imported"
      return 0
    fi
    openshell profile lint -f "$file"
    openshell profile import -f "$file" >/dev/null
    pass "Profile '${id}' imported"
  }
  _ensure_profile "$PROFILE_MAAS_ID" "${rendered}/${PROFILE_MAAS_ID}.yaml"
  _ensure_profile "$PROFILE_NEMO_ID" "${rendered}/${PROFILE_NEMO_ID}.yaml"

  if openshell provider list 2>/dev/null | grep -q "${PROVIDER_DIRECT}"; then
    info "Provider '${PROVIDER_DIRECT}' already exists"
  else
    openshell provider create \
      --name "${PROVIDER_DIRECT}" \
      --type "${PROFILE_MAAS_ID}" \
      --credential "OPENAI_API_KEY=${MAAS_API_KEY}"
    pass "Provider '${PROVIDER_DIRECT}' created"
  fi

  if openshell provider list 2>/dev/null | grep -q "${PROVIDER_GUARDRAILED}"; then
    info "Provider '${PROVIDER_GUARDRAILED}' already exists"
  else
    # NeMo forwards to MaaS with its own key; sandbox may send a dummy Bearer.
    openshell provider create \
      --name "${PROVIDER_GUARDRAILED}" \
      --type "${PROFILE_NEMO_ID}" \
      --credential "OPENAI_API_KEY=unused"
    pass "Provider '${PROVIDER_GUARDRAILED}' created"
  fi
}

active_inference_base_url() {
  case "${1:-$INFERENCE_BACKEND}" in
    guardrailed) printf '%s\n' "$NEMO_GUARDRAILS_URL" ;;
    *) printf '%s\n' "$MAAS_BASE_URL" ;;
  esac
}

active_inference_provider() {
  case "${1:-$INFERENCE_BACKEND}" in
    guardrailed) printf '%s\n' "$PROVIDER_GUARDRAILED" ;;
    *) printf '%s\n' "$PROVIDER_DIRECT" ;;
  esac
}

# Current OpenClaw models.providers.inference.baseUrl inside the sandbox (or empty).
read_openclaw_inference_base_url() {
  openshell sandbox exec -n "$SANDBOX_NAME" --no-tty --timeout 15 -- \
    python3 -c 'import json;print(json.load(open("/sandbox/workspace/.openclaw/openclaw.json"))["models"]["providers"]["inference"]["baseUrl"])' 2>/dev/null || true
}

# Attached sandbox provider names as comma-separated list.
read_openshell_sandbox_providers() {
  openshell sandbox provider list "$SANDBOX_NAME" -o json 2>/dev/null | python3 -c \
    "import sys,json; d=json.load(sys.stdin); print(','.join(p.get('name','') for p in d.get('providers',[])))" 2>/dev/null || true
}

# Fail if attached provider host allowlist cannot serve openclaw.json baseUrl.
# Observed failure (2026-10-30): maas-guardrailed attached while baseUrl still
# pointed at MaaS → Node fetch EACCES, Control UI "Couldn't connect to the AI service".
assert_openshell_inference_aligned() {
  local backend="${1:-}"
  local want_prov want_base got_prov got_base
  load_inference_config || return 1
  if [[ -n "$backend" ]]; then
    want_prov="$(active_inference_provider "$backend")"
    want_base="$(active_inference_base_url "$backend")"
  else
    want_prov=""
    want_base=""
  fi
  got_prov="$(read_openshell_sandbox_providers)"
  got_base="$(read_openclaw_inference_base_url)"
  if [[ -n "$want_prov" && ",${got_prov}," != *",${want_prov},"* ]]; then
    error "Inference provider mismatch: want '${want_prov}', attached '${got_prov:-none}'"
    return 1
  fi
  if [[ -n "$want_base" && "$got_base" != "$want_base" ]]; then
    error "Inference baseUrl mismatch: want '${want_base}', openclaw.json has '${got_base:-empty}'"
    return 1
  fi
  # Host allowlist vs baseUrl (catches partial switch even when backend unset).
  if [[ ",${got_prov}," == *",${PROVIDER_GUARDRAILED},"* && "$got_base" != *nemo* && "$got_base" != *guardrail* ]]; then
    error "Desync: provider ${PROVIDER_GUARDRAILED} attached but baseUrl is '${got_base}' (expected NeMo). Node fetch will EACCES."
    return 1
  fi
  if [[ ",${got_prov}," == *",${PROVIDER_DIRECT},"* && "$got_base" != *maas* && -n "$got_base" ]]; then
    error "Desync: provider ${PROVIDER_DIRECT} attached but baseUrl is '${got_base}' (expected MaaS)."
    return 1
  fi
  return 0
}

attach_openshell_inference_backend() {
  local backend="${1:-}"
  [[ "$backend" == "direct" || "$backend" == "guardrailed" ]] || {
    error "backend must be direct|guardrailed (got: ${backend:-empty})"
    return 1
  }
  load_inference_config || return 1

  local want other
  want="$(active_inference_provider "$backend")"
  if [[ "$backend" == "guardrailed" ]]; then
    other="$PROVIDER_DIRECT"
  else
    other="$PROVIDER_GUARDRAILED"
  fi

  # Hot path (Change 1/2): skip ensure when both providers already exist.
  # Full ensure is ~3s of profile/provider list round-trips (observed 2026-11-02).
  if openshell provider list 2>/dev/null | grep -q "${PROVIDER_DIRECT}" \
    && openshell provider list 2>/dev/null | grep -q "${PROVIDER_GUARDRAILED}"; then
    :
  else
    ensure_openshell_inference_providers || return 1
  fi

  step "Attaching inference provider '${want}' (backend=${backend})"
  # Detach without --wait: OpenShell 0.1.6+ returns in <1s with
  # "persisted (waiting_for_supervisor)". The subsequent attach --wait
  # reconciles both operations (~9s) instead of paying --wait twice
  # (~9s+~9s ≈ 18–21s of the Change 1/2 wall clock — observed 2026-11-02).
  local detached_other=0
  if openshell sandbox provider list "$SANDBOX_NAME" 2>/dev/null | grep -q "$other"; then
    openshell sandbox provider detach "$SANDBOX_NAME" "$other" || true
    detached_other=1
    info "Detached ${other} (async; attach --wait will reconcile)"
  fi
  if openshell sandbox provider list "$SANDBOX_NAME" 2>/dev/null | grep -q "$want"; then
    if [[ "$detached_other" -eq 1 ]]; then
      # want already attached but detach still pending — re-attach --wait
      # forces supervisor reconciliation before we patch/restart OpenClaw.
      openshell sandbox provider attach "$SANDBOX_NAME" "$want" --wait
    fi
    info "Provider '${want}' already attached"
  else
    openshell sandbox provider attach "$SANDBOX_NAME" "$want" --wait
    pass "Attached ${want}"
  fi
  export INFERENCE_BACKEND="$backend"
}

patch_openclaw_inference_base_url() {
  local backend="${1:-$INFERENCE_BACKEND}"
  local base_url model patch_out got
  load_inference_config || return 1
  base_url="$(active_inference_base_url "$backend")"
  model="$INFERENCE_MODEL"

  step "Patching OpenClaw inference baseUrl → ${base_url} (model=${model})"
  # Must use oc exec -i: without -i the heredoc never reaches python in the pod
  # (exit 0, empty stdout) so baseUrl stays stale — provider attach alone then
  # causes Node EACCES / Control UI "Couldn't connect to the AI service".
  local pod
  pod="$(resolve_sandbox_pod "$NAMESPACE" "$SANDBOX_NAME")" || {
    error "Sandbox pod for '${SANDBOX_NAME}' not found"
    return 1
  }
  patch_out=$(oc -n "$NAMESPACE" exec -i "$pod" -c agent -- \
    env BASE_URL="$base_url" MODEL="$model" python3 - <<'PY'
import json, os
path = "/sandbox/workspace/.openclaw/openclaw.json"
base = os.environ["BASE_URL"]
model = os.environ["MODEL"]
with open(path) as f:
    cfg = json.load(f)
prov = cfg.setdefault("models", {}).setdefault("providers", {}).setdefault("inference", {})
prov["baseUrl"] = base
prov["apiKey"] = "${OPENAI_API_KEY}"
models = prov.setdefault("models", [])
if models:
    models[0]["id"] = model
    models[0]["name"] = model
else:
    models.append({
        "id": model, "name": model, "reasoning": True,
        "input": ["text", "image"], "contextWindow": 200000,
        "maxTokens": 64000, "compat": {"supportsStore": False},
    })
agents = cfg.setdefault("agents", {}).setdefault("defaults", {})
agents.setdefault("model", {})["primary"] = f"inference/{model}"
agents.setdefault("models", {})[f"inference/{model}"] = {"alias": model}
agents.get("models", {}).pop("inference/router", None)
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
print("ok", base, model)
PY
) || {
    error "oc exec patch of openclaw.json failed"
    return 1
  }
  if [[ "$patch_out" != *"ok ${base_url}"* ]]; then
    error "openclaw.json patch did not confirm write (output: ${patch_out:-empty})"
    return 1
  fi
  got="$(read_openclaw_inference_base_url)"
  if [[ "$got" != "$base_url" ]]; then
    error "openclaw.json baseUrl not updated (want ${base_url}, got ${got:-empty})"
    return 1
  fi
  pass "openclaw.json inference endpoint updated"
}

restart_openclaw_gateway_process() {
  local GATEWAY_ENV="/sandbox/workspace/.openclaw/gateway.env"
  step "Restarting OpenClaw gateway (provider-aware env)"
  # Kill via /proc/*/cmdline — pgrep -x fails (COMM 15-char truncate).
  # Also reap stuck spawn-broker workers (ERR_SPAWN_BROKER_UNAVAILABLE /
  # kill EPERM after a half-dead gateway — observed 2026-11-02).
  # Do NOT pkill -f: -f matches this bash -c line and SIGKILLs the sandbox exec.
  openshell sandbox exec -n "$SANDBOX_NAME" --no-tty --timeout 20 -- bash -c "
    self=\$\$
    for c in /proc/[0-9]*/cmdline; do
      pid=\$(basename \"\$(dirname \"\$c\")\")
      [[ \"\$pid\" == \"\$self\" || \"\$pid\" == 1 ]] && continue
      cmd=\$(tr '\\0' ' ' < \"\$c\" 2>/dev/null || true)
      case \"\$cmd\" in
        *openclaw*|*spawn-broker*)
          kill -9 \"\$pid\" 2>/dev/null || true
          ;;
      esac
    done
    for _ in 1 2 3 4 5; do
      leftover=0
      for c in /proc/[0-9]*/cmdline; do
        cmd=\$(tr '\\0' ' ' < \"\$c\" 2>/dev/null || true)
        case \"\$cmd\" in *openclaw*|*spawn-broker*) leftover=1; break ;; esac
      done
      [[ \$leftover -eq 0 ]] && break
      sleep 0.2
    done
    rm -f /sandbox/workspace/.openclaw/state/*.lock /tmp/openclaw*/*.lock 2>/dev/null
    mkdir -p /sandbox/workspace/.openclaw/tmp
    if [[ -f ${GATEWAY_ENV} ]]; then
      grep -vE '^(TMPDIR|SQLITE_TMPDIR|OPENCLAW_TEMP)=' ${GATEWAY_ENV} > ${GATEWAY_ENV}.tmp || true
      mv ${GATEWAY_ENV}.tmp ${GATEWAY_ENV}
      printf '%s\n' 'TMPDIR=/sandbox/workspace/.openclaw/tmp' \
        'SQLITE_TMPDIR=/sandbox/workspace/.openclaw/tmp' \
        'OPENCLAW_TEMP=/sandbox/workspace/.openclaw/tmp' >> ${GATEWAY_ENV}
      chmod 600 ${GATEWAY_ENV}
    fi
    true
  " >/dev/null 2>&1 || true

  # Start gateway, then verify /health in a *separate* sandbox exec.
  # Do NOT curl-/health-poll inside the start exec: OpenShell 0.1.6 has been
  # observed to SIGKILL that session (Killed: 9 → UI 502).
  # OpenClaw 2026.10.x: process COMM appears immediately, but HTTP /health only
  # after ~10s (http.bound). Fixed sleep 12 covers bootstrap; external /health
  # poll catches the tail. Old sleep 18 wasted ~6s on every Change 1/2 switch.
  local _restart_log
  _restart_log="$(mktemp)"
  if ! openshell sandbox exec -n "$SANDBOX_NAME" --no-tty --timeout 60 \
    --env "HOME=/sandbox/workspace" \
    --env "TMPDIR=/sandbox/workspace/.openclaw/tmp" \
    --env "SQLITE_TMPDIR=/sandbox/workspace/.openclaw/tmp" \
    --env "OPENCLAW_TEMP=/sandbox/workspace/.openclaw/tmp" \
    --env "PATH=/sandbox/workspace/.npm-global/bin:/usr/local/bin:/usr/bin:/bin" \
    -- bash -c "
      set -a
      # shellcheck disable=SC1091
      [[ -f ${GATEWAY_ENV} ]] && source ${GATEWAY_ENV}
      set +a
      export PATH=/sandbox/workspace/.npm-global/bin:/usr/local/bin:/usr/bin:/bin
      export TMPDIR=/sandbox/workspace/.openclaw/tmp
      export SQLITE_TMPDIR=/sandbox/workspace/.openclaw/tmp
      export OPENCLAW_TEMP=/sandbox/workspace/.openclaw/tmp
      : > /sandbox/workspace/openclaw.log
      nohup openclaw gateway run >> /sandbox/workspace/openclaw.log 2>&1 &
      disown
      sleep 12
      if grep -lrx openclaw-gatewa /proc/*/comm >/dev/null 2>&1; then
        echo OK
        exit 0
      fi
      echo FAIL
      tail -40 /sandbox/workspace/openclaw.log
      exit 1
    " >"${_restart_log}" 2>&1; then
    error "OpenClaw gateway restart failed"
    cat "${_restart_log}" >&2 || true
    rm -f "${_restart_log}"
    return 1
  fi
  grep -E 'OK|FAIL' "${_restart_log}" || true
  rm -f "${_restart_log}"

  # /health may still be 0–3s behind sleep 12 — poll outside the start session.
  local _h
  for _h in 1 2 3 4 5 6 7 8; do
    if openshell sandbox exec -n "$SANDBOX_NAME" --no-tty --timeout 15 \
      --env "HOME=/sandbox/workspace" \
      -- bash -c 'curl -sf -m 2 http://127.0.0.1:18789/health >/dev/null'; then
      pass "OpenClaw gateway restarted"
      return 0
    fi
  done
  error "OpenClaw gateway restarted but /health failed"
  openshell sandbox exec -n "$SANDBOX_NAME" --no-tty --timeout 10 \
    -- bash -c 'tail -40 /sandbox/workspace/openclaw.log' >&2 || true
  return 1
}

switch_openshell_inference() {
  local backend="$1"
  # Idempotent fast-path: demo-reset / verify beforeAll call this when already
  # on the target backend. Skipping a no-op gateway restart keeps Control UI
  # sessions alive and avoids burning the Playwright beforeAll budget
  # (observed 2026-11-02: ~30s restart even when already direct).
  if assert_openshell_inference_aligned "$backend" >/dev/null 2>&1; then
    info "Inference already aligned to ${backend} — skipping attach/patch/restart"
    pass "Inference backend → ${backend} ($(active_inference_provider "$backend") → $(active_inference_base_url "$backend"))"
    return 0
  fi
  attach_openshell_inference_backend "$backend"
  patch_openclaw_inference_base_url "$backend"
  restart_openclaw_gateway_process
  assert_openshell_inference_aligned "$backend" || {
    error "Inference switch to '${backend}' left provider/baseUrl misaligned — Control UI will show connection errors"
    return 1
  }
  pass "Inference backend → ${backend} ($(active_inference_provider "$backend") → $(active_inference_base_url "$backend"))"
}

# CLI entrypoint when executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  cmd="${1:-}"
  case "$cmd" in
    ensure)
      ensure_openshell_inference_providers
      ;;
    switch)
      switch_openshell_inference "${2:-}"
      ;;
    attach)
      attach_openshell_inference_backend "${2:-}"
      ;;
    *)
      echo "Usage: $0 ensure | switch direct|guardrailed | attach direct|guardrailed" >&2
      exit 2
      ;;
  esac
fi
