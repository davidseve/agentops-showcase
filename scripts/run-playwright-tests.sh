#!/usr/bin/env bash
# run-playwright-tests.sh — export Playwright env (URLs, MLflow experiment id) and run tests.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

if [[ -f "$SECRETS_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$SECRETS_FILE"
  set +a
fi

export_playwright_env
warn_playwright_mlflow_oauth_missing

# Durable OS browser cache (Cursor may inject a sandbox PLAYWRIGHT_BROWSERS_PATH).
if [[ "$(uname -s)" == "Darwin" ]]; then
  export PLAYWRIGHT_BROWSERS_PATH="${HOME}/Library/Caches/ms-playwright"
else
  export PLAYWRIGHT_BROWSERS_PATH="${HOME}/.cache/ms-playwright"
fi

# OpenClaw 2026.10+ retired gateway.controlUi.dangerouslyDisableDeviceAuth.
# Control UI auth waits on Message input until devices are approved — without
# a watcher, Playwright auth.setup times out (observed 2026-11-02).
APPROVE_PID=""
cleanup_device_approve() {
  if [[ -n "${APPROVE_PID}" ]] && kill -0 "${APPROVE_PID}" 2>/dev/null; then
    kill "${APPROVE_PID}" 2>/dev/null || true
    wait "${APPROVE_PID}" 2>/dev/null || true
  fi
}
trap cleanup_device_approve EXIT
info "Auto-approving pending Control UI device pairing during Playwright"
"${SCRIPT_DIR}/openclaw-approve-pending-devices.sh" --watch >/dev/null 2>&1 &
APPROVE_PID=$!

cd "${PROJECT_DIR}/tests"
npx playwright test "$@"
status=$?
cleanup_device_approve
trap - EXIT
exit "$status"
