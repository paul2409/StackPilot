#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# scripts/core/service-up.sh
#
# Purpose:
#   Canonical service startup entrypoint for StackPilot.
#
# Guarantees:
#   1) Services are started ONLY from /vagrant inside the VM
#   2) Compose ALWAYS builds the application image from local source
#   3) Same command works on control/worker1/worker2 via NODE
#
# Usage:
#   bash scripts/core/service-up.sh
#   NODE=worker1 bash scripts/core/service-up.sh
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

echo "== service-up: starting stack on node '${NODE}' =="

# ----------------------------------------------------------
# Enter the Vagrant environment on the HOST
# ----------------------------------------------------------
cd "$VAGRANT_DIR"

# ----------------------------------------------------------
# Execute service startup INSIDE the VM
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

echo '== compose build (local source) =='
BUILDKIT_PROGRESS=plain docker compose -f "$COMPOSE_FILE" build

echo '== compose up =='
docker compose -f "$COMPOSE_FILE" up -d

echo '== compose ps =='
docker compose -f "$COMPOSE_FILE" ps
EOF

echo "== service-up: done =="
