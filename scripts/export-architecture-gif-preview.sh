#!/usr/bin/env bash
# Generate three temporary GIF variants for comparison (not for commit).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TESTS_DIR="${ROOT_DIR}/tests"
PREVIEW_DIR="${ROOT_DIR}/assets/preview"

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

export PLAYWRIGHT_BROWSERS_PATH=0
(cd "${TESTS_DIR}" && npx playwright install chromium)

mkdir -p "${PREVIEW_DIR}"

run_variant() {
  local name="$1"
  local last_index="$2"
  local fps="$3"
  local out="${PREVIEW_DIR}/overall-architecture-${name}.gif"

  echo ""
  echo "==> Variant: ${name} (hops 0..${last_index}, ${fps} fps) -> ${out}"
  (
    cd "${TESTS_DIR}"
    ARCH_GIF_LAST_INDEX="${last_index}" \
    ARCH_GIF_FPS="${fps}" \
    ARCH_GIF_OUTPUT="${out}" \
    node export-architecture-gif.mjs
  )
}

# 1) Request path only — End user through LLM (7 hops)
run_variant "request-path" 6 2

# 2) Request + response — through Landlock round-trip (14 hops)
run_variant "request-response" 13 2

# 3) Full baseline — all hops including egress + MLflow trace (22 hops)
run_variant "full" 21 3

echo ""
echo "==> Preview GIFs written to ${PREVIEW_DIR}/"
ls -lh "${PREVIEW_DIR}"/overall-architecture-*.gif
