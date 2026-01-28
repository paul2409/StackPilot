#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# scripts/core/service-down.sh
#
# Purpose:
#   Safe “stop the stack” command for day-to-day use.
#
# What this script DOES:
#   - Stops and removes Docker Compose containers (API + Postgres)
#   - Removes the compose network
#   - Leaves images intact (no rebuild forcing)
#   - Leaves volumes intact (no data wipe)
#
# What this script DOES NOT do (by design):
#   - Does NOT delete images (that is clean-room’s job)
#   - Does NOT delete volumes (persistence proof depends on them existing)
#   - Does NOT verify system correctness (verify is separate)
#
# Usage:
#   bash scripts/core/service-down.sh
#   NODE=worker1 bash scripts/core/service-down.sh
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

# ----------------------------------------------------------
# Runtime parameters
# ----------------------------------------------------------
NODE="${NODE:-control}"

echo "== service-down: node='${NODE}' =="

# ----------------------------------------------------------
# Enter Vagrant environment on the host
# ----------------------------------------------------------
cd "$VAGRANT_DIR"

# ----------------------------------------------------------
# Execute stop logic INSIDE the VM
# ----------------------------------------------------------
vagrant ssh "$NODE" -c "bash -s" <<'EOF'
set -euo pipefail

APP_DIR="/vagrant"
COMPOSE_FILE="infra/docker-compose.yml"

cd "$APP_DIR"

echo '== preflight: enforce /vagrant execution =='
if [ "$(pwd)" != "/vagrant" ]; then
  echo 'FAIL: script must be executed from /vagrant inside the VM'
  echo "Current directory: $(pwd)"
  echo 'Expected directory: /vagrant'
  echo 'Fix: ensure the repo is mounted at /vagrant and rerun.'
  exit 1
fi
echo 'PASS: running from /vagrant'

echo '== 1) Stop and remove compose containers (keep images/volumes) =='
docker compose -f "$COMPOSE_FILE" down --remove-orphans

echo '== 2) Verify: no compose containers remain =='
if docker compose -f "$COMPOSE_FILE" ps -q | grep -q .; then
  echo 'FAIL: compose still reports containers:'
  docker compose -f "$COMPOSE_FILE" ps
  exit 1
fi

echo 'PASS: containers removed; images + volumes preserved'
EOF

echo "== service-down: done =="
