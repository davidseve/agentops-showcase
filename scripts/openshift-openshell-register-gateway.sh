#!/usr/bin/env bash
# Register the cluster OpenShell gateway with the local CLI (mTLS).
#
# Idempotent: skips remove+add when this GATEWAY_NAME is already registered
# and `openshell status` succeeds after an explicit select. Always selects
# GATEWAY_NAME before status checks — `openshell status` only reports on
# whichever alias is currently selected, and a different alias may be
# selected locally from a previous run/gateway.
#
# Called automatically by: make -C deploy deploy-openshell
# Standalone:              GATEWAY_NAME=ocp ./scripts/openshift-openshell-register-gateway.sh
set -euo pipefail

NAMESPACE="${NAMESPACE:-openshell}"
GATEWAY_NAME="${GATEWAY_NAME:-ocp}"
SECRET="${OPENSHELL_CLIENT_TLS_SECRET:-openshell-client-tls}"
OPENSHELL_CONFIG_DIR="${OPENSHELL_CONFIG_DIR:-${HOME}/.config/openshell}"
MTLS_DIR="${OPENSHELL_CONFIG_DIR}/gateways/${GATEWAY_NAME}/mtls"
STATUS_RETRIES="${STATUS_RETRIES:-40}"
STATUS_SLEEP="${STATUS_SLEEP:-5}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log()  { printf '==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

command -v oc >/dev/null 2>&1 || die "oc is required"
command -v openshell >/dev/null 2>&1 || die "openshell CLI is required"
command -v base64 >/dev/null 2>&1 || die "base64 is required"

# Global OPENSHELL_GATEWAY_INSECURE breaks client-cert mTLS.
unset OPENSHELL_GATEWAY_INSECURE || true

GW_ROUTE="$(oc -n "${NAMESPACE}" get route openshell-gw -o jsonpath='{.spec.host}' 2>/dev/null || true)"
[[ -n "${GW_ROUTE}" ]] || die "Route openshell-gw not found in namespace ${NAMESPACE} (deploy OpenShell first)"
log "Gateway Route: https://${GW_ROUTE}"

# `openshell gateway list` marks the selected alias with a leading `*` column
# (`* ocp https://...`), so the name is $1 when idle and $2 when selected.
_gateway_list_name_field() {
  # Prints: name<TAB>endpoint_url for each row (header skipped).
  openshell gateway list 2>/dev/null | awk '
    NR<=1 { next }
    {
      if ($1 == "*") { name=$2; ep=$3 }
      else { name=$1; ep=$2 }
      print name "\t" ep
    }
  '
}

gateway_listed() {
  _gateway_list_name_field | awk -F'\t' -v n="${GATEWAY_NAME}" '
    $1==n { found=1 }
    END { exit !found }
  '
}

# openshell status only reports on the *currently selected* alias — select
# ours first so a different, healthy alias selected locally cannot fake
# "already connected".
#
# Also compare the registered endpoint host to the live Route. A prior cluster
# (e.g. agentops-demojam vs agentops-demojam-latest) can still answer
# `openshell status` and would otherwise skip re-register — then sandbox
# create fails with protobuf/schema mismatches across gateway versions
# (observed 2026-10-28: CLI 0.1.6 → stale 0.0.83 gateway).
gateway_endpoint_host() {
  _gateway_list_name_field | awk -F'\t' -v n="${GATEWAY_NAME}" '
    $1==n {
      ep=$2
      sub(/^https:\/\//,"",ep)
      sub(/\/.*/,"",ep)
      sub(/:.*/,"",ep)
      print ep
      exit
    }
  '
}

GATEWAY_ALREADY_REGISTERED=false
STALE_ENDPOINT=false
if gateway_listed; then
  GATEWAY_ALREADY_REGISTERED=true
  openshell gateway select "${GATEWAY_NAME}" &>/dev/null || true
  registered_host="$(gateway_endpoint_host)"
  if [[ -n "${registered_host}" && "${registered_host}" != "${GW_ROUTE}" ]]; then
    STALE_ENDPOINT=true
    log "Gateway '${GATEWAY_NAME}' points at ${registered_host}, cluster Route is ${GW_ROUTE} — re-registering"
  fi
fi

if [[ "${GATEWAY_ALREADY_REGISTERED}" != "true" ]] \
  || [[ "${STALE_ENDPOINT}" == "true" ]] \
  || ! openshell status &>/dev/null; then
  openshell gateway remove "${GATEWAY_NAME}" 2>/dev/null || true
  openshell gateway add "https://${GW_ROUTE}" --local --name "${GATEWAY_NAME}"
  openshell gateway select "${GATEWAY_NAME}"
  # gateway add overwrites mtls/ with a local Podman bundle — restore cluster certs.
  NAMESPACE="${NAMESPACE}" GATEWAY_NAME="${GATEWAY_NAME}" \
    "${SCRIPT_DIR}/openshift-openshell-sync-mtls.sh"
  openshell gateway select "${GATEWAY_NAME}"
else
  log "Gateway '${GATEWAY_NAME}' already registered and reachable — skipping re-register"
fi

log "Waiting for openshell status"
retries=0
until openshell status; do
  retries=$((retries + 1))
  if [[ ${retries} -ge ${STATUS_RETRIES} ]]; then
    die "openshell status failed after ${retries} attempts"
  fi
  info "Gateway connection not ready yet, retrying (${retries}/${STATUS_RETRIES})..."
  sleep "${STATUS_SLEEP}"
done

log "CLI registered: alias '${GATEWAY_NAME}' → https://${GW_ROUTE}"
