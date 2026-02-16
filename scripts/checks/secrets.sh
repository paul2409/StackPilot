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
# This is a *guardrail*, not a full security scanner.
# It should catch obvious leaks with low false positives.
#
# IMPORTANT
# ---------
# - Demo env files with fake credentials are allowed explicitly
# - This script MUST NOT scan itself (it contains patterns)
# ==========================================================

PASS="PASS"
FAIL="FAIL"

say() { printf "%s\n" "$*"; }
ok()  { say "${PASS}: $*"; }
bad() { say "${FAIL}: $*" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# This script contains patterns by design
SELF_PATH="scripts/checks/secrets.sh"

# Allowlist: demo env files with fake credentials
ALLOWLIST_FILES=(
  "apps/mock-exchange/env/dev.env"
  "apps/mock-exchange/env/dev.worker1.env"
)

# Allowlist: files where "secrets." references are expected (not real secrets)
ALLOWLIST_SECRETS_REF_PREFIXES=(
  ".github/workflows/"
)

is_allowlisted() {
  local candidate="$1"
  for allow in "${ALLOWLIST_FILES[@]}"; do
    [[ "$candidate" == "$allow" ]] && return 0
  done
  return 1
}

is_allowlisted_secrets_ref_file() {
  local candidate="$1"
  for p in "${ALLOWLIST_SECRETS_REF_PREFIXES[@]}"; do
    [[ "$candidate" == "$p"* ]] && return 0
  done
  return 1
}

# ==========================================================
# CHECK 1: BLOCKED FILE TYPES (tracked)
# ==========================================================
say "== Check: tracked secret-like files =="

# These should NEVER be committed
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

for pattern in "${BLOCKED_TRACKED_PATTERNS[@]}"; do
  while IFS= read -r file; do
    [[ -n "$file" ]] && tracked_hits+=("$file")
  done < <(git ls-files "$pattern" 2>/dev/null || true)
done

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

# Only match things that look like REAL secret material.
# DO NOT match variable names like AWS_ACCESS_KEY_ID; those cause false positives.
PATTERNS=(
  # AWS access key IDs (real leaked key format)
  "AKIA[0-9A-Z]{16}"

  # Common private key blocks
  "BEGIN RSA PRIVATE KEY"
  "BEGIN OPENSSH PRIVATE KEY"
  "BEGIN EC PRIVATE KEY"
  "PRIVATE KEY-----"

  # GitHub classic token (ghp_) format
  "ghp_[A-Za-z0-9]{36}"

  # GitHub fine-grained token prefix
  "github_pat_"

  # Common URL-with-credentials (user:pass@host)
  "://[^/[:space:]]+:[^/[:space:]]+@"

  # Obvious “inline secret assignment” (only if it looks non-empty and not a placeholder)
  "(^|[[:space:]])(API_KEY|SECRET_KEY|PASSWORD)[[:space:]]*=[[:space:]]*[^[:space:]]{6,}"
)

regex="$(IFS="|"; echo "${PATTERNS[*]}")"

scan_hits="$(
  git ls-files -z \
  | while IFS= read -r -d '' f; do
      # Skip this script itself
      [[ "$f" == "$SELF_PATH" ]] && continue

      # Skip allowlisted demo env files
      is_allowlisted "$f" && continue

      # Skip binaries
      if file -b --mime "$f" | grep -q "charset=binary"; then
        continue
      fi

      # Special case: workflow files are allowed to reference secrets.*
      # (that’s not a secret leak, it’s correct usage)
      if is_allowlisted_secrets_ref_file "$f"; then
        # Still scan for real secret material (AKIA, private keys, tokens, user:pass@)
        grep -nE --color=never "$regex" "$f" 2>/dev/null || true
        continue
      fi

      # Eligible file → scan
      grep -nE --color=never "$regex" "$f" 2>/dev/null || true
    done
)"

if [[ -n "$scan_hits" ]]; then
  say "${FAIL}: possible secrets detected in tracked files:"
  say "$scan_hits"
  say "Fix: remove secrets, rotate credentials if real, and commit sanitized config only"
  exit 1
fi

ok "no obvious secrets detected in tracked content (demo env files excluded)"

say "== Secrets safety checks passed =="
exit 0