#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# Secrets Safety Gate
#
# PURPOSE
# -------
# This script prevents accidental leakage of credentials or
# private keys into the git repository.
#
# DESIGN PHILOSOPHY
# -----------------
# - Be conservative and explicit
# - Fail loudly on real mistakes
# - Allow intentional demo shortcuts, but document them
#
# IMPORTANT PROJECT NOTE
# ----------------------
# This repository intentionally includes demo environment
# files with dummy credentials to keep the lab frictionless.
# These specific files are allowlisted and excluded from
# secret-pattern scanning by design.
#
# This is a safety gate, NOT a full security scanner.
# ==========================================================


# ----------------------------------------------------------
# Standardized output helpers
# ----------------------------------------------------------
# These ensure consistent, readable output across all checks.
PASS="PASS"
FAIL="FAIL"

say() { printf "%s\n" "$*"; }
ok()  { say "${PASS}: $*"; }
bad() { say "${FAIL}: $*" >&2; exit 1; }


# ----------------------------------------------------------
# Resolve repository root directory
# ----------------------------------------------------------
# This script lives at: scripts/checks/secrets.sh
# Moving two levels up reliably lands us at repo root.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"


# ----------------------------------------------------------
# Allowlist: demo env files with intentional dummy secrets
# ----------------------------------------------------------
# These files are intentionally committed for demo purposes.
# They MAY contain passwords or credentials, but:
# - they are non-production
# - they are explicitly acknowledged here
# - they are excluded from secret-pattern scanning only
#
# IMPORTANT:
# These files are still subject to the "blocked file" rules
# below (e.g., we still block private keys).
ALLOWLIST_FILES=(
  "apps/mock-exchange/env/dev.env"
  "apps/mock-exchange/env/dev.worker1.env"
)


# ----------------------------------------------------------
# Helper: check if a file is allowlisted
# ----------------------------------------------------------
# Returns success if the given path matches an allowlisted file.
is_allowlisted() {
  local candidate="$1"
  local allow
  for allow in "${ALLOWLIST_FILES[@]}"; do
    [[ "$candidate" == "$allow" ]] && return 0
  done
  return 1
}


# ==========================================================
# CHECK 1: BLOCKED SECRET-LIKE FILES
# ==========================================================
say "== Check: tracked secret-like files =="

# These patterns should NEVER be committed, even in a demo.
# If any of these are tracked, we fail immediately.
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

# For each blocked pattern, check whether git is tracking
# any matching files.
for pattern in "${BLOCKED_TRACKED_PATTERNS[@]}"; do
  while IFS= read -r file; do
    [[ -n "$file" ]] && tracked_hits+=("$file")
  done < <(git ls-files "$pattern" 2>/dev/null || true)
done

# If we found any blocked files, fail and explain why.
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

# These are intentionally obvious patterns.
# The goal is to catch accidents, not perform deep inspection.
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

# Build a single extended regex for grep.
regex="$(IFS="|"; echo "${PATTERNS[*]}")"


# ----------------------------------------------------------
# Scan logic
# ----------------------------------------------------------
# Steps:
# 1) Enumerate tracked files only (git ls-files)
# 2) Skip allowlisted demo env files
# 3) Skip binary files
# 4) Grep remaining files for secret patterns
scan_hits="$(
  git ls-files -z \
  | while IFS= read -r -d '' f; do
      # Skip files explicitly allowlisted
      if is_allowlisted "$f"; then
        continue
      fi

      # Skip binary files (certs, images, etc.)
      if file -b --mime "$f" | grep -q "charset=binary"; then
        continue
      fi

      # Pass eligible files forward for scanning
      printf "%s\0" "$f"
    done \
  | xargs -0 grep -nE --color=never "$regex" 2>/dev/null || true
)"

# If any matches are found, fail and show exact locations.
if [[ -n "$scan_hits" ]]; then
  say "${FAIL}: possible secrets detected in tracked files:"
  say "$scan_hits"
  say "Fix: remove secrets, rotate credentials if real, and commit sanitized config only"
  exit 1
fi

ok "no obvious secrets detected in tracked content (demo env files excluded)"


# ----------------------------------------------------------
# Final success message
# ----------------------------------------------------------
say "== Secrets safety checks passed =="
exit 0
