#!/usr/bin/env bash
set -euo pipefail
#
# ==========================================================
# Repo Policy Gate (scripts/policy.sh)
# ==========================================================
#
# Why this script exists:
# - This repo is meant to be "reviewable" and "self-policing".
# - Before running any demo/verify/build workflows, we enforce
#   basic invariants that prevent confusing failures later.
#
# What this script checks:
# 1) Required files exist (repo layout must match expectations)
# 2) Shell scripts under scripts/ are executable (no forgotten chmod +x)
# 3) The compose file exists in the expected location (infra/)
# 4) If Docker is available on this machine, validate that the compose
#    file is syntactically/structurally correct using `docker compose config`
#    (this does NOT require containers to be running).
#
# Behavior rules:
# - Fail fast with a single clear reason (non-zero exit).
# - Print PASS/FAIL/SKIP lines that a reviewer can trust.
# - On machines without Docker (e.g. Windows host without Docker Desktop),
#   we still enforce repo layout + script permissions, but we SKIP compose
#   structural validation because we cannot run docker/compose commands.
#
# ==========================================================

# Standardized status prefixes for consistent output
PASS="PASS"
FAIL="FAIL"

# Print a normal line
say() { printf "%s\n" "$*"; }

# Print a PASS line
ok()  { say "${PASS}: $*"; }

# Print a FAIL line and terminate the script with exit code 1
bad() { say "${FAIL}: $*" >&2; exit 1; }

# ----------------------------------------------------------
# Resolve repository root directory
# ----------------------------------------------------------
# This allows the script to be executed from anywhere (repo root,
# subfolders, or via Makefile) while still using consistent paths.
#
# Example:
#   ./scripts/policy.sh
#   (or)
#   make verify   -> which calls ./scripts/policy.sh
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# ----------------------------------------------------------
# Helper: command existence check
# ----------------------------------------------------------
# Returns success (0) if the command exists on PATH, otherwise failure (1).
# Used to check whether docker / docker-compose is available.
have_cmd() { command -v "$1" >/dev/null 2>&1; }

# ----------------------------------------------------------
# Helper: require a file to exist
# ----------------------------------------------------------
# Fails immediately if the required file is missing.
require_file() {
  local f="$1"
  [[ -f "$f" ]] || bad "missing required file: $f"
}

# ----------------------------------------------------------
# Helper: require a script to exist AND be executable
# ----------------------------------------------------------
# Fails immediately if:
# - the file is missing
# - or it exists but does not have the executable bit set
require_exec() {
  local f="$1"
  [[ -f "$f" ]] || bad "required script missing: $f"
  [[ -x "$f" ]] || bad "script not executable: $f (chmod +x $f)"
}

# ==========================================================
# 1) REQUIRED FILES CHECK
# ==========================================================
say "== Policy: required files =="

# This list defines the baseline "shape" of the repo.
# If any of these files are missing, the repo is not considered
# runnable/reviewable and downstream scripts should not proceed.
REQUIRED_FILES=(
  "../README.md"
  "../Makefile"
  "../vagrant/Vagrantfile"
  "../infra/docker-compose.yml"
  "../apps/mock-exchange/Dockerfile"
  "../apps/mock-exchange/app.py"
  "../apps/mock-exchange/requirements.txt"
  "../apps/mock-exchange/env/dev.env"
)

# Iterate through the list and enforce file existence.
for f in "${REQUIRED_FILES[@]}"; do
  require_file "$f"
  ok "file exists: $f"
done



# ==========================================================
# 2) SCRIPT EXECUTABILITY CHECK
# ==========================================================
say "== Policy: script executability =="

# Self-check: this policy script must be runnable.
# This prevents situations where the repo requires policy enforcement
# but the gate itself cannot be executed.
require_exec "checks/policy.sh"

# Strict list of core scripts that must exist and be executable.
# Keep this list aligned with your actual golden-path scripts.
REQUIRED_EXEC=(
  "core/service-up.sh"
  "core/service-down.sh"
  "ops/dockerlogs.sh"
  "provision/provision.sh"
  "provision/install-docker.sh"
  "ops/hosts.sh"
  "ops/netdiag.sh"
  "access/ssh-control.sh"
  "access/ssh-worker1.sh"
  "access/ssh-worker2.sh"
  "verify/verify-host.sh"
  "verify/verify-cluster.sh"
  "verify/verify-build.sh"
  "drills/db-ready.sh"
)

# Enforce existence + executability for the core list.
for f in "${REQUIRED_EXEC[@]}"; do
  require_exec "$f"
    ok "script exists and executable: $f"
done

# Broader rule: every *.sh under scripts/ must be executable.
# This catches new scripts added later where the developer forgets chmod +x.
#
# find -print0 and read -d '' handle filenames safely (spaces, etc.)
while IFS= read -r -d '' file; do
  [[ -x "$file" ]] || bad "script not executable: $file (chmod +x $file)"
done < <(find "scripts" -type f -name "*.sh" -print0)

ok "script permissions valid"

# ==========================================================
# 3) COMPOSE FILE PRESENCE + STRUCTURAL VALIDATION
# ==========================================================
say "== Policy: docker compose validation =="

# This repo expects the compose file to live in infra/.
# We prove the file exists even if Docker is not installed on this machine.
COMPOSE_FILE="../infra/docker-compose.yml"
require_file "$COMPOSE_FILE"
ok "compose file present: $COMPOSE_FILE"

# Docker may not exist on the host machine (common on Windows hosts).
# In that case:
# - do not fail the entire policy gate
# - explicitly SKIP compose structure validation
# - still pass the policy gate because repo layout + permissions were enforced
if ! have_cmd docker; then
  say "SKIP: docker not available on PATH (compose validation requires Docker)"
  say "== Policy checks passed =="
  exit 0
fi

# Determine which compose command is available:
# - Prefer modern plugin: `docker compose`
# - Fallback to legacy binary: `docker-compose`
if docker compose version >/dev/null 2>&1; then
  COMPOSE=(docker compose)
elif have_cmd docker-compose; then
  COMPOSE=(docker-compose)
else
  bad "docker compose not available"
fi

# Validate compose structure. This does not start containers.
# It checks YAML correctness and compose schema validity.
"${COMPOSE[@]}" -f "$COMPOSE_FILE" config >/dev/null
ok "$COMPOSE_FILE valid"

# Optional: validate a worker1 override compose file if present.
# This is only validated when Docker/compose is available.
if [[ -f "infra/docker-compose.worker1.yml" ]]; then
  "${COMPOSE[@]}" -f "infra/docker-compose.worker1.yml" config >/dev/null
  ok "infra/docker-compose.worker1.yml valid"
fi

# If we reached here, all enforced checks passed (and any skips were explicit).
say "== Policy checks passed =="
exit 0