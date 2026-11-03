#!/usr/bin/env bash
# validate-openclaw-session.sh — Prove Control UI chat can use session storage.
#
# /health alone stays "live" when SQLite/FTS session stores are broken; the UI
# then fails with "Couldn't finish this reply" / chat.history UNAVAILABLE.
# This sensor exercises the gateway WebSocket path the Control UI uses.
#
# Exit 0 = session store reachable via gateway RPC
# Exit 1 = unhealthy / session store unavailable
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=common.sh
source "${SCRIPT_DIR}/common.sh"

command -v openshell >/dev/null 2>&1 || { error "openshell CLI is required"; exit 1; }

openshell gateway select "${GATEWAY_NAME}" >/dev/null 2>&1 || true

step "OpenClaw session store (gateway RPC)"

# 1) Loopback health inside the sandbox netns
if ! openshell sandbox exec -n "${SANDBOX_NAME}" --no-tty --timeout 15 \
  --env "HOME=/sandbox/workspace" \
  -- bash -c 'curl -sf http://127.0.0.1:18789/health' >/dev/null; then
  fail "Gateway /health failed inside sandbox"
  exit 1
fi
pass "Gateway /health live"

# 2) sessions.list over the same WS path Control UI uses (catches SQLite/FTS breakage)
SESS_OUT="$(openshell sandbox exec -n "${SANDBOX_NAME}" --no-tty --timeout 25 \
  --env "HOME=/sandbox/workspace" \
  --env "PATH=/sandbox/workspace/.npm-global/bin:/usr/local/bin:/usr/bin:/bin" \
  -- bash -c '
    set -euo pipefail
    PW=$(python3 -c "import json; print(json.load(open(\"/sandbox/workspace/.openclaw/openclaw.json\"))[\"gateway\"][\"auth\"][\"password\"])")
    openclaw gateway call sessions.list --json --password "$PW" --timeout 12000 --params "{}"
  ' 2>/dev/null || true)"

if echo "$SESS_OUT" | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
if not raw:
  raise SystemExit(2)
try:
  d = json.loads(raw)
except json.JSONDecodeError:
  raise SystemExit(2)
# Success shape has count/totalCount; failure has error.code UNAVAILABLE / gateway_request_error
err = d.get("error") or {}
if err:
  raise SystemExit(1)
if "count" not in d and "totalCount" not in d:
  raise SystemExit(2)
' 2>/dev/null; then
  pass "gateway sessions.list OK (session store reachable)"
else
  fail "gateway sessions.list failed — session store likely broken (UI chat will fail)"
  # Do not dump password-bearing command output; show error shape only.
  echo "$SESS_OUT" | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
try:
  d = json.loads(raw)
  err = d.get("error") or d
  print("  detail:", json.dumps(err)[:400])
except Exception:
  print("  detail: (non-JSON or empty RPC response)")
' 2>/dev/null || true
  exit 1
fi

# 3) FTS5 write probe via *dedicated* files only (never open live gateway DBs)
if openshell sandbox exec -n "${SANDBOX_NAME}" --no-tty --timeout 15 \
  -- bash -c '
python3 - <<'"'"'PY'"'"'
import os, sqlite3
tmpdir = "/sandbox/workspace/.openclaw/tmp"
os.makedirs(tmpdir, exist_ok=True)
os.makedirs("/sandbox/workspace/.openclaw/state", exist_ok=True)
os.makedirs("/sandbox/workspace/.openclaw/agents/main/agent", exist_ok=True)
os.environ["TMPDIR"] = tmpdir
os.environ["SQLITE_TMPDIR"] = tmpdir
probes = [
  "/sandbox/workspace/.openclaw/state/.fts-probe.sqlite",
  "/sandbox/workspace/.openclaw/agents/main/agent/.fts-probe.sqlite",
]
errs = []
for p in probes:
  try:
    if os.path.exists(p):
      os.remove(p)
    c = sqlite3.connect(p)
    c.execute("create virtual table if not exists __agentops_fts_probe using fts5(x)")
    c.execute("insert into __agentops_fts_probe(x) values (?)", ("ok",))
    c.commit()
    c.close()
  except Exception as e:
    errs.append(f"{p}: {e}")
  finally:
    if os.path.exists(p):
      os.remove(p)
if errs:
  print("FAIL", "; ".join(errs))
  raise SystemExit(1)
print("OK")
PY
  ' >/dev/null; then
  pass "SQLite FTS5 writable under .openclaw/state and agents/*/agent"
else
  fail "SQLite FTS5 probe failed (state/agent) — Control UI chat.send will fail"
  exit 1
fi

# 4) gateway.env must pin SQLITE temp dirs (empty TMPDIR → FTS5 shadow-table failures in Node)
# Linux COMM is 15 chars → process shows as "openclaw-gatewa"; use /proc/*/comm not pgrep -x.
if openshell sandbox exec -n "${SANDBOX_NAME}" --no-tty --timeout 10 \
  -- bash -c '
envf=/sandbox/workspace/.openclaw/gateway.env
[ -f "$envf" ] || { echo "missing gateway.env"; exit 1; }
grep -q "^TMPDIR=/sandbox/workspace/.openclaw/tmp$" "$envf" || { echo "TMPDIR missing in gateway.env"; exit 1; }
grep -q "^SQLITE_TMPDIR=/sandbox/workspace/.openclaw/tmp$" "$envf" || { echo "SQLITE_TMPDIR missing in gateway.env"; exit 1; }
grep -lrx "openclaw-gatewa" /proc/*/comm >/dev/null 2>&1 || { echo "openclaw-gateway not running"; exit 1; }
echo OK
  ' >/dev/null; then
  pass "gateway.env TMPDIR/SQLITE_TMPDIR + openclaw-gateway running"
else
  fail "gateway.env missing TMPDIR/SQLITE_TMPDIR or gateway not running — relaunch via launch-openclaw.sh"
  exit 1
fi

# 5) No FTS/SQLite hard errors since last listen (chat can fail while sessions.list passes)
if openshell sandbox exec -n "${SANDBOX_NAME}" --no-tty --timeout 10 \
  -- bash -c '
log=/sandbox/workspace/openclaw.log
[ -f "$log" ] || { echo OK; exit 0; }
start=$(grep -n "http server listening" "$log" | tail -1 | cut -d: -f1)
start=${start:-1}
tail -n +"$start" "$log" | grep -E "SqliteError|fts5:.*unable to open database|OpenClawAgentDatabaseMediaMigrationRequiredError" && exit 1
echo OK
  ' >/dev/null; then
  pass "No FTS5/SQLite/migration errors since last gateway listen"
else
  fail "openclaw.log shows DB errors after gateway start — wipe agents/*/agent/*.sqlite* and restart with TMPDIR set"
  exit 1
fi

# 6) chat.send smoke (sessions.list alone missed agent-DB FTS breakage)
CHAT_OUT="$(openshell sandbox exec -n "${SANDBOX_NAME}" --no-tty --timeout 90 \
  --env "HOME=/sandbox/workspace" \
  --env "PATH=/sandbox/workspace/.npm-global/bin:/usr/local/bin:/usr/bin:/bin" \
  -- bash -c '
    set -euo pipefail
    PW=$(python3 -c "import json; print(json.load(open(\"/sandbox/workspace/.openclaw/openclaw.json\"))[\"gateway\"][\"auth\"][\"password\"])")
    openclaw gateway call chat.send --json --password "$PW" --timeout 60000 \
      --params "{\"sessionKey\":\"agent:main:main\",\"message\":\"agentops-session-probe: reply with ok\",\"idempotencyKey\":\"session-probe-$(date +%s)\"}"
  ' 2>/dev/null || true)"

if echo "$CHAT_OUT" | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
if not raw:
  raise SystemExit(2)
d = json.loads(raw)
err = d.get("error") or {}
if err:
  raise SystemExit(1)
# Accept started/ok/completed shapes
if d.get("ok") is False:
  raise SystemExit(1)
if d.get("status") in ("started", "ok", "completed", None) or d.get("runId"):
  raise SystemExit(0)
raise SystemExit(2)
' 2>/dev/null; then
  pass "gateway chat.send OK (agent session store usable)"
else
  fail "gateway chat.send failed — Control UI will show Could not finish this reply"
  echo "$CHAT_OUT" | python3 -c '
import sys, json
raw = sys.stdin.read().strip()
try:
  d = json.loads(raw)
  err = d.get("error") or d
  print("  detail:", json.dumps(err)[:400])
except Exception:
  print("  detail: (non-JSON or empty RPC response)")
' 2>/dev/null || true
  exit 1
fi

pass "OpenClaw session store ready for Control UI chat"
