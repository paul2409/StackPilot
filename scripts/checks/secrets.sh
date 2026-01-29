#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# Secrets Safety Gate
#
# PURPOSE
# -------
# Prevent committing real secrets (keys, passwords, tokens)
# into the repository.
#
# This is a *guardrail*, not a security scanner.
# It is intentionally simple and conservative.
#
# IMPORTANT
# ---------
# - Demo env files with fake credentials are allowed explicitly
# - This script MUST NOT scan itself (it contains the patterns)
# ==========================================================


# ----------------------------------------------------------
# Output helpers (consistent, readable messages)
# ----------------------------------------------------------
PASS="PASS"
FAIL="FAIL"

say() { printf "%s\n" "$*"; }
ok()  { say "${PASS}: $*"; }
bad() { say "${FAIL}: $*" >&2; exit 1; }


# ----------------------------------------------------------
# Resolve repository root
# ----------------------------------------------------------
# Script location: scripts/checks/secrets.sh
# Two levels up always lands at repo root.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"


# ----------------------------------------------------------
# Self-exclusion
# ----------------------------------------------------------
# This script contains the secret patterns by design.
# It MUST NOT scan itself or it will false-positive.
SELF_PATH="scripts/checks/secrets.sh"


# ----------------------------------------------------------
# Allowlist: demo env files with fake credentials
# ----------------------------------------------------------
# These files are intentionally committed for demo purposes.
# They may contain PASSWORD= or API_KEY= but are non-production.
ALLOWLIST_FILES=(
  "apps/mock-exchange/env/dev.env"
  "apps/mock-exchange/env/dev.worker1.env"
)


# ----------------------------------------------------------
# Helper: check if file is allowlisted
# ----------------------------------------------------------
is_allowlisted() {
  local candidate="$1"
  for allow in "${ALLOWLIST_FILES[@]}"; do
    [[ "$candidate" == "$allow" ]] && return 0
  done
  return 1
}


# ==========================================================
# CHECK 1: BLOCKED FILE TYPES
# ==========================================================
say "== Check: tracked secret-like files =="

# These file types should NEVER be committed, even in demos
BLOCKED_TRACKED_PATTERNS=(
  ".env"
  ".env.*"
  "*.pem"
  "*.key"
  "*.p12"
  "*.pfx"
  "id_rsa"
  "id_ed25519"
  "secrets.*"
)

tracked_hits=()

# Check git-tracked files against blocked patterns
for pattern in "${BLOCKED_TRACKED_PATTERNS[@]}"; do
  while IFS= read -r file; do
    [[ -n "$file" ]] && tracked_hits+=("$file")
  done < <(git ls-files "$pattern" 2>/dev/null || true)
done

# Fail if any blocked files are tracked
if ((${#tracked_hits[@]} > 0)); then
  say "${FAIL}: blocked secret-like files are tracked:"
  for f in "${tracked_hits[@]}"; do
    say "  - $f"
  done
  say "Fix: remove from git tracking and add to .gitignore"
  exit 1
fi

ok "no blocked secret-like files tracked"


# ==========================================================
# CHECK 2: SECRET PATTERNS IN TRACKED FILE CONTENT
# ==========================================================
say "== Check: secret patterns in tracked files =="

# Intentionally obvious patterns to catch accidents
PATTERNS=(
  "AWS_ACCESS_KEY_ID"
  "AWS_SECRET_ACCESS_KEY"
  "AKIA[0-9A-Z]{16}"
  "BEGIN RSA PRIVATE KEY"
  "BEGIN OPENSSH PRIVATE KEY"
  "BEGIN EC PRIVATE KEY"
  "PRIVATE KEY-----"
  "ghp_[A-Za-z0-9]{36}"
  "github_pat_"
  "DATABASE_URL=.*://"
  "API_KEY="
  "SECRET_KEY="
  "PASSWORD="
)

# Build grep regex
regex="$(IFS="|"; echo "${PATTERNS[*]}")"


# ----------------------------------------------------------
# Scan logic
# ----------------------------------------------------------
# Rules:
# - only scan git-tracked files
# - skip this script
# - skip allowlisted demo env files
# - skip binary files
scan_hits="$(
  git ls-files -z \
  | while IFS= read -r -d '' f; do
      # Skip this script itself
      if [[ "$f" == "$SELF_PATH" ]]; then
        continue
      fi

      # Skip allowlisted demo env files
      if is_allowlisted "$f"; then
        continue
      fi

      # Skip binary files
      if file -b --mime "$f" | grep -q "charset=binary"; then
        continue
      fi

      # Eligible file → scan
      printf "%s\0" "$f"
    done \
  | xargs -0 grep -nE --color=never "$regex" 2>/dev/null || true
)"

# Fail if any secret-like patterns are found
if [[ -n "$scan_hits" ]]; then
  say "${FAIL}: possible secrets detected in tracked files:"
  say "$scan_hits"
  say "Fix: remove secrets, rotate credentials if real, and commit sanitized config only"
  exit 1
fi

ok "no obvious secrets detected in tracked content (demo env files excluded)"


# ----------------------------------------------------------
# Final success
# ----------------------------------------------------------
say "== Secrets safety checks passed =="
exit 0