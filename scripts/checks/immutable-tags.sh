#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# Immutable Image Tag Contract
#
# Rules:
# - No :latest tags
# - No implicit tags
# - Allowlisted dev-only exceptions are permitted
# ==========================================================

PASS="PASS"
FAIL="FAIL"

say() { printf "%s\n" "$*"; }
ok()  { say "${PASS}: $*"; }
bad() { say "${FAIL}: $*" >&2; exit 1; }

say "== Immutable image tag contract =="

COMPOSE_FILE="infra/docker-compose.yml"
[ -f "$COMPOSE_FILE" ] || bad "compose file missing: $COMPOSE_FILE"

# ----------------------------------------------------------
# Allowed image references (explicit exceptions)
# ----------------------------------------------------------
# These are dev-safe, intentional, and reviewed.
ALLOWLIST=(
  "infra-api:local"
  "postgres:16.4-alpine"
)

is_allowlisted() {
  local img="$1"
  for allowed in "${ALLOWLIST[@]}"; do
    [[ "$img" == "$allowed" ]] && return 0
  done
  return 1
}

# ----------------------------------------------------------
# Extract image references from compose file
# ----------------------------------------------------------
mapfile -t IMAGES < <(
  awk '/^[[:space:]]*image:[[:space:]]*/ {print $2}' "$COMPOSE_FILE"
)

[ "${#IMAGES[@]}" -gt 0 ] || bad "no images found in compose file"

# ----------------------------------------------------------
# Enforce rules
# ----------------------------------------------------------
for image in "${IMAGES[@]}"; do
  # Allowlisted images bypass strict checks
  if is_allowlisted "$image"; then
    ok "allowlisted image accepted: $image"
    continue
  fi

  # Block explicit :latest
  if [[ "$image" == *":latest" ]]; then
    bad "explicit :latest tag not allowed: $image"
  fi

  # Block implicit tags (no colon at all)
  if [[ "$image" != *":"* ]]; then
    bad "implicit :latest not allowed (missing tag): $image"
  fi
done

ok "immutable image tag contract passed"
exit 0