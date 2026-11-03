#!/usr/bin/env bash
# openclaw-approve-pending-devices.sh — Demo break-glass for Control UI pairing.
#
# OpenClaw 2026.10+ retired gateway.controlUi.dangerouslyDisableDeviceAuth
# (the key is ignored). Browsers must pair once via `openclaw devices approve`.
# For the AgentOps demo we auto-approve pending Control UI requests.
#
# Usage:
#   ./scripts/openclaw-approve-pending-devices.sh           # approve once
#   ./scripts/openclaw-approve-pending-devices.sh --watch   # poll until Ctrl-C
#   ./scripts/openclaw-approve-pending-devices.sh --wait 90 # poll up to N seconds
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

WATCH=false
WAIT_SECS=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --watch) WATCH=true; shift ;;
    --wait)
      WAIT_SECS="${2:?}"
      shift 2
      ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) error "Unknown arg: $1"; exit 2 ;;
  esac
done

command -v openshell >/dev/null 2>&1 || { error "openshell CLI is required"; exit 1; }
openshell gateway select "${GATEWAY_NAME}" >/dev/null 2>&1 || true

approve_once() {
  local out
  out="$(openshell sandbox exec -n "${SANDBOX_NAME}" --no-tty --timeout 30 \
    --env "HOME=/sandbox/workspace" \
    --env "PATH=/sandbox/workspace/.npm-global/bin:/usr/local/bin:/usr/bin:/bin" \
    -- bash -c '
python3 - <<'"'"'PY'"'"'
import json, re, subprocess

def approve(rid: str) -> None:
    subprocess.check_call(["openclaw", "devices", "approve", rid])
    print(f"APPROVED {rid}")

raw = subprocess.check_output(["openclaw", "devices", "list", "--json"], text=True)
data = json.loads(raw)
pending = data.get("pending") or []
seen: set[str] = set()

for req in pending:
    rid = req.get("requestId") or req.get("id") or req.get("request") or ""
    if isinstance(rid, dict):
        rid = rid.get("id") or ""
    if rid and rid not in seen:
        seen.add(rid)
        approve(rid)

if not seen:
    # Fallback: human table — UUIDs in the Pending section only
    text = subprocess.check_output(["openclaw", "devices", "list"], text=True)
    section = text.split("Paired")[0] if "Paired" in text else text
    if "Pending" not in section and "pending" not in section.lower():
        print("NONE")
        raise SystemExit(0)
    for rid in re.findall(
        r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}",
        section,
    ):
        if rid not in seen:
            seen.add(rid)
            approve(rid)

if not seen:
    print("NONE")
PY
    ' 2>/dev/null || echo FAIL)"

  if echo "$out" | grep -q '^APPROVED '; then
    echo "$out" | grep '^APPROVED ' | while read -r line; do pass "$line"; done
    return 0
  fi
  if echo "$out" | grep -qx 'NONE'; then
    return 1
  fi
  warn "device approve probe returned: ${out:-empty}"
  return 1
}

if [[ "$WATCH" == "true" ]]; then
  info "Watching for pending Control UI device pairing (Ctrl-C to stop)"
  while true; do
    approve_once || true
    sleep 3
  done
fi

if (( WAIT_SECS > 0 )); then
  info "Waiting up to ${WAIT_SECS}s for pending Control UI pairing…"
  deadline=$((SECONDS + WAIT_SECS))
  approved=false
  while (( SECONDS < deadline )); do
    if approve_once; then
      approved=true
      break
    fi
    sleep 2
  done
  if [[ "$approved" == "true" ]]; then
    pass "Pending Control UI device(s) approved"
    exit 0
  fi
  info "No pending device requests within ${WAIT_SECS}s (open Control UI once if needed)"
  exit 0
fi

if approve_once; then
  pass "Pending Control UI device(s) approved"
else
  info "No pending Control UI device requests"
fi
