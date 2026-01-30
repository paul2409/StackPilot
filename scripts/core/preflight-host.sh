#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# scripts/core/preflight.sh
#
# Phase 1 Step 5:
# Fail fast on the HOST before we attempt any VM or service work.
#
# Checks:
#  - required commands exist (vagrant, virtualbox, ssh)
#  - repo layout looks correct (vagrant/ exists)
#
# Output:
#  - PASS/FAIL with concrete remediation
# ==========================================================

# ----------------------------------------------------------
# Resolve repo root safely (works from scripts/core/, scripts/verify/, etc.)
# ----------------------------------------------------------
ROOT_DIR=""
if command -v git >/dev/null 2>&1; then
  ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "${ROOT_DIR:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

VAGRANT_DIR="${ROOT_DIR}/vagrant"

fail() {
  echo "FAIL: $1"
  echo "Fix:  $2"
  exit 1
}

pass() {
  echo "PASS: $1"
}

echo "== preflight (host) =="

# 1) Repo structure sanity
[ -d "${VAGRANT_DIR}" ] || fail \
  "missing vagrant/ directory at ${VAGRANT_DIR}" \
  "run from the repo root, or re-clone the repository and try again"

[ -f "${VAGRANT_DIR}/Vagrantfile" ] || fail \
  "missing Vagrantfile at ${VAGRANT_DIR}/Vagrantfile" \
  "ensure the repo is complete; re-clone if needed"

pass "repo structure looks valid"

# 2) Vagrant presence
command -v vagrant >/dev/null 2>&1 || fail \
  "vagrant not installed" \
  "install Vagrant, then confirm: vagrant --version"

pass "vagrant found: $(vagrant --version | head -n 1)"

# 3) VirtualBox presence (since you're using VirtualBox provider)
if command -v VBoxManage >/dev/null 2>&1; then
  pass "VirtualBox found: $(VBoxManage --version 2>/dev/null | head -n 1)"
else
  fail \
    "VirtualBox not found (VBoxManage missing)" \
    "install VirtualBox, then confirm: VBoxManage --version"
fi

# 4) SSH presence (used by scripts and vagrant ssh under the hood)
command -v ssh >/dev/null 2>&1 || fail \
  "ssh client not found" \
  "install OpenSSH client (or enable it on your OS), then retry"

pass "ssh client present"

echo "== preflight (host): PASS =="
