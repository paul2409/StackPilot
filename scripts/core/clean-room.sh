#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# scripts/core/clean-room.sh
#
# Clean-room teardown for Milestone 03.
# What it does (on NODE inside the VM):
#  1) Stops and removes ALL compose containers (API + Postgres)
#  2) Verifies compose containers are gone (PASS/FAIL)
#  3) Removes ONLY the locally-built APP image (infra-api)
#     - Does NOT delete Postgres image
#     - Does NOT delete volumes (no data wipe)
#  4) Verifies the APP image is gone (PASS/FAIL)
#  5) Prunes UNUSED Docker build cache (no images, no volumes)
#
# Why this exists:
#  - To PROVE the golden path rebuilds from scratch (no stale images or cache luck).
#
# Usage:
#  NODE=control bash scripts/core/clean-room.sh
#  NODE=worker1 bash scripts/core/clean-room.sh
#
# Optional override:
#  APP_IMAGE=infra-api:local NODE=worker1 bash scripts/core/clean-room.sh
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

# Target node (control by default)
NODE="${NODE:-control}"

# Your API image name (matches compose `image:`)
APP_IMAGE="${APP_IMAGE:-infra-api:local}"

echo "== clean-room: node=${NODE} =="

cd "$VAGRANT_DIR"

# Run cleanup inside the chosen VM.
# NOTE: Everything inside this quoted block is executed on the VM.
# IMPORTANT: Use double quotes so APP_IMAGE is passed from host -> VM.
vagrant ssh "$NODE" -c "bash -s" <<EOF
set -euo pipefail

APP_DIR="/vagrant"
COMPOSE_FILE="infra/docker-compose.yml"
APP_IMAGE="${APP_IMAGE}"

cd "\$APP_DIR"

echo '== preflight: enforce /vagrant execution =='
if [ "\$(pwd)" != "/vagrant" ]; then
  echo 'FAIL: script must be executed from /vagrant inside the VM'
  echo "Current directory: \$(pwd)"
  echo 'Expected directory: /vagrant'
  echo 'Fix: ensure the repo is mounted at /vagrant and rerun.'
  exit 1
fi
echo 'PASS: running from /vagrant'

echo '== 1) Stop and remove ALL compose containers (API + Postgres) =='
docker compose -f "\$COMPOSE_FILE" down --remove-orphans

echo '== 2) Verify: no compose containers remain =='
if docker compose -f "\$COMPOSE_FILE" ps -q | grep -q .; then
  echo 'FAIL: compose still reports containers:'
  docker compose -f "\$COMPOSE_FILE" ps
  exit 1
else
  echo 'PASS: compose containers removed'
fi

echo '== 3) Remove ONLY the APP image. Do NOT touch Postgres image =='
if docker image inspect "\$APP_IMAGE" >/dev/null 2>&1; then
  docker rmi "\$APP_IMAGE"
  echo "PASS: app image removed -> \$APP_IMAGE"
else
  echo "INFO: app image not present (already clean) -> \$APP_IMAGE"
fi

echo '== 4) Verify: APP image is gone =='
if docker image inspect "\$APP_IMAGE" >/dev/null 2>&1; then
  echo "FAIL: app image still exists -> \$APP_IMAGE"
  docker image ls | head -n 30
  exit 1
else
  echo 'PASS: app image confirmed removed'
fi

echo '== 5) Remove unused Docker build cache (no images, no volumes) =='
docker builder prune -f
echo 'PASS: unused Docker build cache pruned'

echo '== 6) Sanity: Postgres image is allowed to remain =='
docker image ls | grep -i postgres || echo 'INFO: postgres image not present (will be pulled next run)'
EOF
echo "== clean-room: done =="