#!/usr/bin/env bash
set -euo pipefail
# validation - build site, start preview, probe with retries, and stop cleanly
WS="/tmp/kavia/workspace/code-generation/voice-assistant-documentation-236916-236917/Documentation"
cd "$WS"
# Ensure PATH includes user bin for this run (in case deps used --user)
export PATH="$HOME/.local/bin:${PATH:-}"
# Capture build output
./build.sh 2>&1 | tee "$WS/build.log"
# Start preview (best-effort)
./preview.sh >/dev/null 2>&1 || true
PID_FILE="$WS/preview.pid"
# Wait for pid file up to 5s
waited=0
while [ ! -f "$PID_FILE" ] && [ $waited -lt 5 ]; do
  sleep 1
  waited=$((waited+1))
done
if [ ! -f "$PID_FILE" ]; then
  echo "preview pid missing after wait" >&2
  echo "--- build.log tail ---" >&2; tail -n 200 "$WS/build.log" >&2 || true
  exit 3
fi
PID=$(cat "$PID_FILE" 2>/dev/null || echo "")
if [ -z "$PID" ]; then echo "empty preview pid" >&2; rm -f "$PID_FILE"; exit 4; fi
# Confirm PID exists and likely a python process
if ! ps -p "$PID" -o comm= >/dev/null 2>&1; then echo "preview process not running (pid $PID)" >&2; rm -f "$PID_FILE"; exit 5; fi
comm=$(ps -p "$PID" -o comm= | tr -d ' ')
if ! echo "$comm" | grep -qi python; then echo "preview pid $PID is not python: $comm" >&2; rm -f "$PID_FILE"; exit 6; fi
# Probe with retries/backoff (10 attempts), record last HTTP code
URL="http://127.0.0.1:8000/index.html"
ok=1
last_code="000"
for i in $(seq 1 10); do
  code=$(curl -sS -o /dev/null -w "%{http_code}" "$URL" 2>/dev/null || echo "000")
  last_code="$code"
  if [ "$code" = "200" ]; then ok=0; break; fi
  sleep $(( i < 4 ? 1 : 2 ))
done
if [ $ok -ne 0 ]; then
  echo "preview probe failed (last_http_code=$last_code)" >&2
  echo "--- build.log tail ---" >&2; tail -n 200 "$WS/build.log" >&2 || true
  echo "--- linkcheck.log tail ---" >&2; tail -n 200 "$WS/build_linkcheck.log" >&2 || true
  # Attempt graceful shutdown
  kill "$PID" >/dev/null 2>&1 || true
  sleep 2
  if ps -p "$PID" >/dev/null 2>&1; then kill -9 "$PID" >/dev/null 2>&1 || true; fi
  rm -f "$PID_FILE"
  exit 7
fi
# Record HTTP status into build.log
echo "probe_http_status=200" >> "$WS/build.log"
# Stop server cleanly: TERM, wait, then KILL if needed
kill "$PID" >/dev/null 2>&1 || true
sleep 2
if ps -p "$PID" >/dev/null 2>&1; then kill -9 "$PID" >/dev/null 2>&1 || true; fi
rm -f "$PID_FILE"
# Evidence
echo "built_site=$WS/build/index.html"
[ -f "$WS/build/index.html" ] && echo "build_exists=true" || echo "build_exists=false"
echo "build_log=$WS/build.log"
echo "linkcheck_log=$WS/build_linkcheck.log"
