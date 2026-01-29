#!/usr/bin/env bash
set -euo pipefail
#
# ==========================================================
# Repo Policy Gate (scripts/checks/policy.sh)
# ==========================================================
#
# Why this script exists:
# - This repo is meant to be "reviewable" and "self-policing".
# - Before running any demo/verify/build workflows, we enforce
#   basic invariants that prevent confusing failures later.
#
# What this script checks:
# 1) Required files exist (repo layout must match expectations)
# 2) Shell scripts under scripts/ are VALID bash scripts
#    (syntax-checked via bash, NOT executable-bit enforced)
# 3) The compose file exists in the expected location (infra/)
# 4) If Docker is available, validate compose structure
#
# Design decision (IMPORTANT):
# - We do NOT enforce the executable bit (+x).
# - Windows + Git makes exec-bit unreliable.
# - Instead, we enforce that scripts are:
#     • present
#     • readable
#     • valid bash (bash -n)
#
# This keeps CI authoritative WITHOUT OS friction.
#
# ==========================================================

PASS="PASS"
FAIL="FAIL"

say() { printf "%s\n" "$*"; }
ok()  { say "${PASS}: $*"; }
bad() { say "${FAIL}: $*" >&2; exit 1; }

# ----------------------------------------------------------
# Resolve repository root
# ----------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# ----------------------------------------------------------
# Helpers
# ----------------------------------------------------------
have_cmd() { command -v "$1" >/dev/null 2>&1; }

require_file() {
  local f="$1"
  [[ -f "$f" ]] || bad "missing required file: $f"
}

require_bash_script() {
  local f="$1"
  [[ -f "$f" ]] || bad "required script missing: $f"
  [[ -r "$f" ]] || bad "script not readable: $f"

  # Syntax check ONLY (portable, OS-safe)
  if ! bash -n "$f" 2>/dev/null; then
    bad "bash syntax error in script: $f"
  fi
}

# ==========================================================
# 1) REQUIRED FILES CHECK
# ==========================================================
say "== Policy: required files =="

REQUIRED_FILES=(
  "README.md"
  "Makefile"
  "vagrant/Vagrantfile"
  "infra/docker-compose.yml"
  "apps/mock-exchange/Dockerfile"
  "apps/mock-exchange/app.py"
  "apps/mock-exchange/requirements.txt"
  "apps/mock-exchange/env/dev.env"
)

for f in "${REQUIRED_FILES[@]}"; do
  require_file "$f"
  ok "file exists: $f"
done

# ==========================================================
# 2) SCRIPT VALIDITY CHECK (OS-SAFE)
# ==========================================================
say "== Policy: script validity (bash syntax) =="

# Self-check
require_bash_script "scripts/checks/policy.sh"
ok "policy script valid bash"

# Core scripts that must exist and be valid bash
REQUIRED_SCRIPTS=(
  "scripts/core/service-up.sh"
  "scripts/core/service-down.sh"
  "scripts/verify/verify-host.sh"
  "scripts/verify/verify-cluster.sh"
  "scripts/verify/verify-build.sh"
  "scripts/drills/db-ready.sh"
)

for f in "${REQUIRED_SCRIPTS[@]}"; do
  require_bash_script "$f"
  ok "script valid: $f"
done

# Broad rule: every *.sh under scripts/ must be valid bash
while IFS= read -r -d '' file; do
  require_bash_script "$file"
done < <(find "scripts" -type f -name "*.sh" -print0)

ok "all scripts are valid bash"

# ==========================================================
# 3) DOCKER COMPOSE STRUCTURE VALIDATION
# ==========================================================
say "== Policy: docker compose validation =="

COMPOSE_FILE="infra/docker-compose.yml"
require_file "$COMPOSE_FILE"
ok "compose file present: $COMPOSE_FILE"

# Docker may not exist on hosted CI / Windows
if ! have_cmd docker; then
  say "SKIP: docker not available (compose validation skipped)"
  say "== Policy checks passed =="
  exit 0
fi

if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif have_cmd docker-compose; then
  COMPOSE=(docker-compose)
else
  bad "docker compose not available"
fi

"${COMPOSE[@]}" -f "$COMPOSE_FILE" config >/dev/null
ok "$COMPOSE_FILE valid"

if [[ -f "infra/docker-compose.worker1.yml" ]]; then
  "${COMPOSE[@]}" -f "infra/docker-compose.worker1.yml" config >/dev/null
  ok "infra/docker-compose.worker1.yml valid"
fi

say "== Policy checks passed =="
exit 0