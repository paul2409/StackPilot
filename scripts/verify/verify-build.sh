#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# scripts/verify/verify-build.sh
#
# PURPOSE (Milestone 03):
#   This script proves build truth inside a VM.
#   It does NOT rely on printed output.
#
# WHAT IT ASSERTS:
#   1) The API container exists
#   2) The API container is running
#   3) The container was started from EXPECTED_IMAGE (repo:tag)
#   4) The container’s image ID matches the tagged image ID
#   5) (Optional) The image was rebuilt after clean-room
#
# WHY THIS MATTERS:
#   Docker can lie by omission:
#   - Containers can run with stale images
#   - Tags can point to one image while containers use another
#   This script fails hard when that happens.
# ==========================================================


# ==========================================================
# BLOCK 1: HOST-SIDE DEFAULTS
# ----------------------------------------------------------
# These variables exist on your HOST machine.
# You can override any of them when running the script.
# ==========================================================
NODE="${NODE:-control}"                        # VM to run checks in
EXPECTED_IMAGE="${EXPECTED_IMAGE:-infra-api:local}"  # Image name we REQUIRE the API to use
API_SERVICE="${API_SERVICE:-api}"              # Service key in docker-compose.yml
COMPOSE_FILE="${COMPOSE_FILE:-infra/docker-compose.yml}"  # Compose file path
STATE_DIR="${STATE_DIR:-.stackpilot/state}"    # Where snapshot files are stored
EXPECT_REBUILD="${EXPECT_REBUILD:-0}"          # Set to 1 to REQUIRE rebuild proof


# ==========================================================
# BLOCK 2: LOCATE REPO ROOT SAFELY
# ----------------------------------------------------------
# This allows the script to be run from anywhere in the repo.
# We prefer git (authoritative).
# If git fails, we fall back to relative paths.
# ==========================================================
ROOT_DIR=""
if command -v git >/dev/null 2>&1; then
  ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi

if [ -z "${ROOT_DIR:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

# Vagrant commands must be run from the directory containing the Vagrantfile
VAGRANT_DIR="${ROOT_DIR}/vagrant"

echo "== verify-build: node='${NODE}' =="


# ==========================================================
# BLOCK 3: MOVE INTO VAGRANT DIRECTORY (HOST)
# ----------------------------------------------------------
# vagrant ssh expects to be executed where the Vagrantfile lives.
# ==========================================================
cd "$VAGRANT_DIR"


# ==========================================================
# BLOCK 4: ENTER THE VM AND RUN ASSERTIONS THERE
# ----------------------------------------------------------
# Everything inside the heredoc runs INSIDE the VM.
#
# We pass required values as environment variables so:
#   - The heredoc stays clean
#   - No accidental host-side variable expansion happens
# ==========================================================
vagrant ssh "$NODE" -c \
  "EXPECTED_IMAGE='${EXPECTED_IMAGE}' \
   API_SERVICE='${API_SERVICE}' \
   COMPOSE_FILE='${COMPOSE_FILE}' \
   STATE_DIR='${STATE_DIR}' \
   EXPECT_REBUILD='${EXPECT_REBUILD}' \
   bash -s" <<'EOF'
set -euo pipefail


# ==========================================================
# VM BLOCK A: VM-SIDE CONSTANTS AND HELPERS
# ----------------------------------------------------------
# These variables now exist INSIDE the VM.
# /vagrant is where the repo is mounted in your setup.
# ==========================================================
APP_DIR="/vagrant"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

cd "$APP_DIR"


# ==========================================================
# VM BLOCK B: PREFLIGHT CHECK
# ----------------------------------------------------------
# We enforce that:
#   - The repo is mounted at /vagrant
#   - All relative paths are therefore trustworthy
# ==========================================================
[ "$(pwd)" = "/vagrant" ] || fail "Must run from /vagrant inside VM."

# Create state directory if it doesn’t exist
mkdir -p "$STATE_DIR"

# Snapshot file name is derived from image name
SNAPSHOT_FILE="${STATE_DIR}/image_id.${EXPECTED_IMAGE//[:\/]/_}.txt"


# ==========================================================
# VM BLOCK C: SNAPSHOT MODE (OPTIONAL)
# ----------------------------------------------------------
# When run with --snapshot:
#   - We record the current image ID of EXPECTED_IMAGE
#   - This allows later proof that a rebuild occurred
# ==========================================================
if [ "${1:-}" = "--snapshot" ]; then
  img_id="$(docker image inspect "$EXPECTED_IMAGE" --format '{{.Id}}' 2>/dev/null || true)"
  [ -n "$img_id" ] || fail "Image tag not found: $EXPECTED_IMAGE (build first)."
  echo "$img_id" > "$SNAPSHOT_FILE"
  pass "Snapshot saved: $SNAPSHOT_FILE"
  echo "  $EXPECTED_IMAGE -> $img_id"
  exit 0
fi


# ==========================================================
# VM BLOCK D: LOCATE THE API CONTAINER
# ----------------------------------------------------------
# We ask docker compose:
#   “Which container belongs to the API service?”
# If none is returned, the service is not running.
# ==========================================================
cid="$(docker compose -f "$COMPOSE_FILE" ps -q "$API_SERVICE" 2>/dev/null || true)"
[ -n "$cid" ] || fail "No container for service '$API_SERVICE'. Is the stack up?"
pass "API container exists: $cid"


# ==========================================================
# VM BLOCK E: ASSERT CONTAINER IS RUNNING
# ----------------------------------------------------------
# A container existing is not enough.
# It must be actively running.
# ==========================================================
running="$(docker inspect "$cid" --format '{{.State.Running}}')"
[ "$running" = "true" ] || fail "Container not running (State.Running=$running)."
pass "API container is running"


# ==========================================================
# VM BLOCK F: ASSERT IMAGE NAME MATCH
# ----------------------------------------------------------
# This checks the repo:tag identity.
# Prevents Docker auto-generated image names from slipping in.
# ==========================================================
image_name="$(docker inspect "$cid" --format '{{.Config.Image}}')"
[ "$image_name" = "$EXPECTED_IMAGE" ] || fail "Image name mismatch.
Expected: $EXPECTED_IMAGE
Found:    $image_name
Fix: Set 'image: $EXPECTED_IMAGE' in the compose API service."
pass "API container uses expected image name"


# ==========================================================
# VM BLOCK G: ASSERT IMAGE ID MATCH
# ----------------------------------------------------------
# This checks the immutable truth:
#   The container must be running the same image ID
#   that the EXPECTED_IMAGE tag points to.
# ==========================================================
container_image_id="$(docker inspect "$cid" --format '{{.Image}}')"
tag_image_id="$(docker image inspect "$EXPECTED_IMAGE" --format '{{.Id}}' 2>/dev/null || true)"
[ -n "$tag_image_id" ] || fail "Expected image tag missing locally."

[ "$container_image_id" = "$tag_image_id" ] || fail "Image ID mismatch.
Container: $container_image_id
Tag:       $tag_image_id
Fix: clean-room must delete $EXPECTED_IMAGE, then rebuild."
pass "API container image ID matches tag"


# ==========================================================
# VM BLOCK H: OPTIONAL REBUILD PROOF
# ----------------------------------------------------------
# If EXPECT_REBUILD=1:
#   - A snapshot MUST exist
#   - The current image ID MUST differ from snapshot
# ==========================================================
if [ "$EXPECT_REBUILD" = "1" ]; then
  [ -f "$SNAPSHOT_FILE" ] || fail "No snapshot found."
  prev="$(cat "$SNAPSHOT_FILE" || true)"
  [ -n "$prev" ] || fail "Snapshot file empty."

  [ "$prev" != "$tag_image_id" ] || fail "Rebuild NOT proven.
Snapshot: $prev
Current:  $tag_image_id"

  pass "Rebuild proven (image ID changed)"
fi


# ==========================================================
# VM BLOCK I: CONTEXT OUTPUT (NON-AUTHORITATIVE)
# ----------------------------------------------------------
# This is for humans.
# The proof already happened above.
# ==========================================================
docker compose -f "$COMPOSE_FILE" ps

pass "verify-build PASSED (build truth proven)"
EOF

echo "== verify-build: done =="
