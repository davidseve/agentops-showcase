#!/usr/bin/env bash
# validate-traces.sh — Confirm mlflow-openclaw exported at least one trace.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

if [[ -f "$SECRETS_FILE" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$SECRETS_FILE"
  set +a
fi

command -v openshell >/dev/null 2>&1 || { error "openshell CLI is required"; exit 1; }
openshell gateway select "${GATEWAY_NAME}" >/dev/null 2>&1 || true

step "MLflow Trace Validation"
ensure_mlflow_experiment || {
  error "could not ensure MLflow experiment"
  exit 1
}

POD="$(resolve_sandbox_pod "$NAMESPACE" "$SANDBOX_NAME")" || {
  error "Sandbox pod for '${SANDBOX_NAME}' not found"
  exit 1
}

# Stage a tiny fetch script, then run with node via openshell (egress allowlist).
oc -n "$NAMESPACE" exec -i "$POD" -c agent -- \
  tee /sandbox/workspace/.openclaw/tmp/fetch-mlflow-traces.mjs >/dev/null <<'JS'
import fs from "node:fs";
for (const line of fs.readFileSync("/sandbox/workspace/.openclaw/gateway.env", "utf8").split("\n")) {
  const t = line.trim();
  if (!t || t.startsWith("#") || !t.includes("=")) continue;
  const i = t.indexOf("=");
  const k = t.slice(0, i);
  if (!(k in process.env)) process.env[k] = t.slice(i + 1);
}
const id = process.env.MLFLOW_EXPERIMENT_ID || "1";
const ws = process.env.MLFLOW_WORKSPACE || "openshell";
const url =
  "https://mlflow.redhat-ods-applications.svc.cluster.local:8443/mlflow/api/2.0/mlflow/traces" +
  `?experiment_ids=${id}&max_results=5`;
const res = await fetch(url, {
  headers: {
    Authorization: `Bearer ${process.env.MLFLOW_TRACKING_TOKEN}`,
    "X-MLFLOW-WORKSPACE": ws,
  },
});
process.stdout.write(await res.text());
JS

TRACES="$(openshell sandbox exec -n "${SANDBOX_NAME}" --no-tty --timeout 45 \
  --env HOME=/sandbox/workspace -- \
  node /sandbox/workspace/.openclaw/tmp/fetch-mlflow-traces.mjs 2>/dev/null || true)"

COUNT="$(printf '%s' "${TRACES}" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(len(d.get("traces") or []))
except Exception:
    print(0)
')"

if [[ "${COUNT}" -gt 0 ]]; then
  pass "MLflow has traces in experiment openclaw-tracing (id=${MLFLOW_EXPERIMENT_ID}, found ${COUNT})"
  exit 0
fi

error "No traces found in MLflow experiment openclaw-tracing (id=${MLFLOW_EXPERIMENT_ID:-unknown})"
echo "  Response: ${TRACES:-empty}"
echo "  Check: openclaw plugins list | grep mlflow"
echo "  Gateway log should show: http server listening (... mlflow-openclaw ...)"
exit 1
