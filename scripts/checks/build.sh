#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# Artifact Build Contract (scripts/checks/build.sh)
#
# PURPOSE:
#   Prove that the application artifact (Docker image)
#   can be built by CI from this repo.
#
# THIS IS A PRE-RUNTIME CONTRACT:
#   - No VMs
#   - No containers running
#   - No compose up
#
# It answers ONE question:
#   "If this merges, can CI build the deployable image?"
#
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

say "== Build contract: artifact buildability =="

# ----------------------------------------------------------
# Docker availability check
# ----------------------------------------------------------
# Hosted runners usually have Docker.
# Local machines might not.
#
# Rule:
# - If Docker is NOT available → SKIP (honest)
# - If Docker IS available → build MUST succeed
# ----------------------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
  say "${SKIP}: docker not available on PATH"
  say "== Build contract skipped =="
  exit 0
fi

# ----------------------------------------------------------
# Build parameters
# ----------------------------------------------------------
IMAGE_NAME="infra-api:ci-check"
BUILD_CONTEXT="apps/mock-exchange"

# Sanity check: build context must exist
[ -d "$BUILD_CONTEXT" ] || bad "build context missing: $BUILD_CONTEXT"

say "Building image '${IMAGE_NAME}' from '${BUILD_CONTEXT}'"

# ----------------------------------------------------------
# Build the image
# ----------------------------------------------------------
# --pull=false avoids unexpected network changes
# --no-cache is NOT used here (we just want buildability)
# ----------------------------------------------------------
docker build \
  --pull=false \
  -t "$IMAGE_NAME" \
  "$BUILD_CONTEXT"

ok "docker build succeeded"

# ----------------------------------------------------------
# Cleanup (best-effort)
# ----------------------------------------------------------
# We do NOT fail if cleanup fails.
# This is a CI hygiene step only.
# ----------------------------------------------------------
docker image rm "$IMAGE_NAME" >/dev/null 2>&1 || true

say "== Build contract passed =="
exit 0
