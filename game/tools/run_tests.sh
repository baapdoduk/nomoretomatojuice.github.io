#!/usr/bin/env bash
# Headless verification for the Godot project.
#   tools/run_tests.sh            -> import + parse check + all tests
#   tools/run_tests.sh light      -> only tests whose file/method contains "light"
# Env: GODOT=/path/to/godot (default: godot on PATH)
set -uo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"
FILTER="${1:-}"
LOG_DIR="${LOG_DIR:-$(pwd)/.godot/test_logs}"
mkdir -p "$LOG_DIR"

echo "== [1/3] import (builds class cache) =="
"$GODOT" --headless --path . --import >"$LOG_DIR/import.log" 2>&1
if grep -E "SCRIPT ERROR|Parse Error|ERROR: Failed to load script" "$LOG_DIR/import.log"; then
  echo "Import reported script errors (see $LOG_DIR/import.log)"; exit 1
fi

echo "== [2/3] load/parse check of every script & scene =="
"$GODOT" --headless --path . res://tools/check_scripts.tscn >"$LOG_DIR/check.log" 2>&1
check_code=$?
grep -E "SCRIPT ERROR|Parse Error|BAD |checked" "$LOG_DIR/check.log"
[ $check_code -ne 0 ] && { echo "Parse check failed (see $LOG_DIR/check.log)"; exit 1; }

echo "== [3/3] tests =="
args=()
[ -n "$FILTER" ] && args+=(-- "--filter=$FILTER")
"$GODOT" --headless --path . --fixed-fps 60 res://tests/test_runner.tscn "${args[@]}" 2>&1 | tee "$LOG_DIR/tests.log"
code=${PIPESTATUS[0]}
echo "Test exit code: $code (log: $LOG_DIR/tests.log)"
exit $code
