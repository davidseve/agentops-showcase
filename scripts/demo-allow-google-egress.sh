#!/usr/bin/env bash
# demo-allow-google-egress.sh — Live demo Change 1: allowlist google.com egress for Test C.
#
# Change 1 expects direct MaaS inference. If provider/baseUrl are desynced
# (e.g. maas-guardrailed + MaaS URL → Node EACCES), realign to direct first.
#
# Wall clock is dominated by `openshell policy set --wait` (~5–10s OpenShell
# dataplane reload). Skipping --wait only moves that cost into the first
# sandbox exec; redundant assert/pre-read pairs were removed (2026-11-02).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"
# shellcheck source=openshell-inference.sh
source "${SCRIPT_DIR}/openshell-inference.sh"

command -v openshell >/dev/null 2>&1 || { error "openshell CLI is required"; exit 1; }
[[ -f "$POLICY_GOOGLE_EGRESS" ]] || { error "Policy file not found: $POLICY_GOOGLE_EGRESS"; exit 1; }

openshell gateway select "${GATEWAY_NAME}" >/dev/null 2>&1 || true

step "Allowing google.com egress (Change 1)"
info "Sandbox: ${SANDBOX_NAME}"
info "Policy: $(basename "$POLICY_GOOGLE_EGRESS")"

load_inference_config || exit 1

# Provider-only check (CLI list, ~0.7s). Full assert also reads baseUrl via
# sandbox exec (~0.8s more) — unnecessary on the Change 1 happy path where we
# have not yet switched to NeMo.
_prov="$(read_openshell_sandbox_providers)"
if [[ ",${_prov}," != *",${PROVIDER_DIRECT},"* ]]; then
  warn "Inference provider is '${_prov:-none}' (want ${PROVIDER_DIRECT}) — realigning"
  switch_openshell_inference direct
fi

openshell policy set "${SANDBOX_NAME}" --policy "$POLICY_GOOGLE_EGRESS" --wait

_curl_code=$(openshell sandbox exec -n "${SANDBOX_NAME}" --no-tty --timeout 20 -- \
  bash -c 'curl -s -m 5 -o /dev/null -w "%{http_code}" https://google.com 2>/dev/null; echo' | tr -d '[:space:]')
info "Probe curl https://google.com → HTTP ${_curl_code:-?}"
case "${_curl_code}" in
  200|301|302) ;;
  *) error "google.com still not reachable (HTTP ${_curl_code:-timeout})"; exit 1 ;;
esac

pass "Google egress allowed — curl to google.com should succeed; github.com remains blocked"
