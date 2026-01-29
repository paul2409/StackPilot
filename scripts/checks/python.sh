#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# Python Syntax Contract (scripts/checks/python.sh)
#
# PURPOSE:
#   Prove that all Python source files can be parsed
#   by the Python interpreter.
#
# THIS IS NOT:
#   - unit testing
#   - linting
#   - style enforcement
#
# It answers ONE question:
#   "Will Python crash immediately on startup?"
# ==========================================================

PASS="PASS"
FAIL="FAIL"
SKIP="SKIP"

say() { printf "%s\n" "$*"; }
ok()  { say "${PASS}: $*"; }
bad() { say "${FAIL}: $*" >&2; exit 1; }

# ----------------------------------------------------------
# Resolve repo root
# ----------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

say "== Python syntax contract =="

# ----------------------------------------------------------
# Python availability check
# ----------------------------------------------------------
# Hosted runners always have Python.
# Some local hosts might not.
#
# Rule:
# - If python is NOT available → SKIP
# - If python IS available → must compile
# ----------------------------------------------------------
if ! python -V >/dev/null 2>&1; then
  say "${SKIP}: python not available on PATH"
  say "== Python contract skipped =="
  exit 0
fi

# ----------------------------------------------------------
# Compile all Python files
# ----------------------------------------------------------
# This walks the tree and parses *.py files.
# It does NOT execute them.
# ----------------------------------------------------------
TARGET="apps/mock-exchange"

[ -d "$TARGET" ] || bad "python source directory missing: $TARGET"

say "Compiling Python sources: $TARGET"
python -m compileall "$TARGET" >/dev/null

ok "python syntax valid"
say "== Python contract passed =="
exit 0
