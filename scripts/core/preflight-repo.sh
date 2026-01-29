#!/usr/bin/env bash
# ==========================================================
# StackPilot — preflight-repo.sh
#
# Purpose:
# - Repo-safe preflight that MUST succeed on GitHub-hosted runners.
# - Checks only things that should be true everywhere:
#     • required files/folders exist
#     • minimal tooling exists (bash/make)
#
# Hard rule:
# - DO NOT check for Vagrant / VirtualBox here.
#   Those belong in preflight-host.sh only.
# ==========================================================

set -euo pipefail

echo "== preflight (repo) =="

# ----------------------------------------------------------
# Resolve repo root:
# - This script lives at: scripts/core/preflight-repo.sh
# - Repo root is two directories up from this file.
# ----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ----------------------------------------------------------
# Helper for consistent failures
# ----------------------------------------------------------
fail() {
  echo "FAIL: $*" >&2
  exit 1
}

# ----------------------------------------------------------
# Minimal tooling checks:
# - GitHub-hosted runners will have bash.
# - make should exist (but we check anyway so failures are clear).
# ----------------------------------------------------------
command -v bash >/dev/null 2>&1 || fail "bash not available"
command -v make >/dev/null 2>&1 || fail "make not available"

# Optional: print versions for debugging in CI logs
echo "INFO: bash=$(bash --version | head -n1)"
echo "INFO: make=$(make --version | head -n1)"

# ----------------------------------------------------------
# Repo structure sanity:
# - Keep these checks lightweight and non-environment-specific.
# - If any of these fail, your repo is incomplete or miswired.
# ----------------------------------------------------------
[[ -f "${ROOT_DIR}/Makefile" ]] || fail "Makefile missing at repo root"

[[ -d "${ROOT_DIR}/scripts" ]] || fail "scripts/ folder missing"
[[ -d "${ROOT_DIR}/scripts/core" ]] || fail "scripts/core/ folder missing"
[[ -d "${ROOT_DIR}/scripts/checks" ]] || fail "scripts/checks/ folder missing"
[[ -d "${ROOT_DIR}/scripts/verify" ]] || fail "scripts/verify/ folder missing"
[[ -d "${ROOT_DIR}/scripts/ops" ]] || fail "scripts/ops/ folder missing"

# If your repo uses vagrant/ as a required folder, keep this.
# (This does NOT require vagrant installed; it only verifies the folder exists.)
[[ -d "${ROOT_DIR}/vagrant" ]] || fail "vagrant/ folder missing"

# Optional: enforce that the key scripts exist (prevents path drift).
[[ -f "${ROOT_DIR}/scripts/checks/policy.sh" ]] || fail "missing scripts/checks/policy.sh"
[[ -f "${ROOT_DIR}/scripts/checks/secrets.sh" ]] || fail "missing scripts/checks/secrets.sh"
[[ -f "${ROOT_DIR}/scripts/checks/guarantees-map.sh" ]] || fail "missing scripts/checks/guarantees-map.sh"

echo "PASS: repo preflight OK"