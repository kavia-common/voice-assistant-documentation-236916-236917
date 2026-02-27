#!/usr/bin/env bash
set -euo pipefail
WS="/tmp/kavia/workspace/code-generation/voice-assistant-documentation-236916-236917/Documentation"
cd "$WS"
LOG="$WS/build_linkcheck.log"
BUILD_DIR="$WS/build_linkcheck"
if python3 -m pip show sphinx-linkcheck >/dev/null 2>&1; then
  rm -rf "$BUILD_DIR" "$LOG" || true
  echo "Linkcheck run: $(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$LOG"
  rc=0
  sphinx-build -b linkcheck "$WS/source" "$BUILD_DIR" >> "$LOG" 2>&1 || rc=$?
  rc=${rc:-0}
  if [ "$rc" -ne 0 ]; then
    echo "linkcheck failed, see $LOG" >&2
    echo "--- tail of linkcheck log ---" >&2
    tail -n 200 "$LOG" >&2 || true
    exit 4
  fi
else
  echo "$(date -u +%Y-%m-%dT%H:%M:%SZ): sphinx-linkcheck not installed; skipping linkcheck" > "$LOG"
fi
