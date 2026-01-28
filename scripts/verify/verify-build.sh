#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# scripts/verify/verify-build.sh
#
# Purpose:
#   VM-side “truth inspection” for Milestone 03.
#
# Usage:
#   bash scripts/verify/verify-build.sh
#   NODE=worker1 bash scripts/verify/verify-build.sh
# ==========================================================

# ----------------------------------------------------------
# Runtime parameters
# ----------------------------------------------------------
NODE="${NODE:-control}"

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

echo "== verify-build: node='${NODE}' =="

cd "$VAGRANT_DIR"

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

echo '== compose API service snippet (resolved config) =='
docker compose -f "$COMPOSE_FILE" config \
  | sed -n '/services:/,/networks:/p' \
  | sed -n '/api:/,/^[^ ]/p' \
  | sed -n '1,160p'

echo '== local images (top) =='
docker image ls | head -n 25

echo '== running containers (compose ps) =='
docker compose -f "$COMPOSE_FILE" ps
EOF

echo "== verify-build: done =="
