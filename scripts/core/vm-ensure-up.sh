#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# scripts/core/vm-ensure-up.sh
#
# Purpose:
# - Ensure the Vagrant lab is running.
# - If any VM is down, boot the lab (no provision).
# - If vagrant is missing, fail loudly.
#
# Logs:
# - Writes to ci/logs/:
#     - vagrant-status.log
#     - vm-ensure.log
# ==========================================================

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VAGRANT_DIR="${ROOT_DIR}/vagrant"
CI_LOGS_DIR="${ROOT_DIR}/ci/logs"

mkdir -p "${CI_LOGS_DIR}"

log="${CI_LOGS_DIR}/vm-ensure.log"
status_log="${CI_LOGS_DIR}/vagrant-status.log"

say() { printf "%s\n" "$*"; }
fail() { say "FAIL: $*" | tee -a "$log" >&2; exit 1; }

say "== VM: ensure-up (boot if not running) ==" | tee "$log"

if ! command -v vagrant >/dev/null 2>&1; then
  fail "vagrant not found on runner"
fi

# Capture vagrant status safely (some environments return non-zero for edge cases)
set +e
( cd "$VAGRANT_DIR" && vagrant status ) >"$status_log" 2>&1
rc=$?
set -e

if [[ "$rc" -ne 0 ]]; then
  fail "vagrant status failed (see ci/logs/vagrant-status.log)"
fi

# If any machine is not running, boot lab (no provision)
if grep -Eiq "(poweroff|aborted|not created|saved|stopped)" "$status_log"; then
  say "WARN: lab not fully running -> vagrant up --no-provision" | tee -a "$log"
  ( cd "$VAGRANT_DIR" && vagrant up --no-provision ) 2>&1 | tee -a "$log"
  say "PASS: lab boot attempted" | tee -a "$log"
else
  say "PASS: lab already running (no action)" | tee -a "$log"
fi