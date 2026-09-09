#!/usr/bin/env bash
# Export docs/demo/v5/live.html step 0 (Overall Demo) to assets/overall-architecture.gif.
# Frame-by-frame Playwright capture + ffmpeg palettegen. Manual only — not run in CI.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TESTS_DIR="${ROOT_DIR}/tests"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "error: required command not found: $1" >&2
    exit 1
  fi
}

require_cmd python3
require_cmd node
require_cmd npm
require_cmd ffmpeg

if [[ ! -d "${TESTS_DIR}/node_modules/@playwright/test" ]]; then
  echo "==> Installing test dependencies"
  (cd "${TESTS_DIR}" && npm ci)
fi

echo "==> Ensuring Playwright Chromium is installed (project-local)"
export PLAYWRIGHT_BROWSERS_PATH=0
(cd "${TESTS_DIR}" && npx playwright install chromium)

echo "==> Exporting README architecture GIF (baseline hops ${ARCH_GIF_FIRST_INDEX:-0}..${ARCH_GIF_LAST_INDEX:-6})"
(cd "${TESTS_DIR}" && PLAYWRIGHT_BROWSERS_PATH=0 node export-architecture-gif.mjs)
