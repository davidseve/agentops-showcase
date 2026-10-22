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

cd "${PROJECT_DIR}/tests"
exec npx playwright test "$@"
