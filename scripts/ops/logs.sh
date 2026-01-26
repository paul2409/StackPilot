#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# scripts/logs.sh
#
# Host-side wrapper to stream Docker Compose logs
# from inside the selected VM.
#
# Guarantees:
#  - Executed from host
#  - Runs inside VM via vagrant ssh
#  - Enforces /vagrant execution inside VM (P1S3)
#
# Usage:
#   make logs
#   NODE=worker1 make logs
# ==========================================================

ROOT_DIR=""
if command -v git >/dev/null 2>&1; then
  ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "${ROOT_DIR:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

VAGRANT_DIR="${ROOT_DIR}/vagrant"

NODE="${NODE:-control}"
APP_DIR="/vagrant"
COMPOSE_FILE="infra/docker-compose.yml"

echo "== logs: node=${NODE} =="

cd "${VAGRANT_DIR}"

vagrant ssh "${NODE}" -c "
  set -euo pipefail
  cd ${APP_DIR}

  echo '== preflight: enforce /vagrant execution =='
  if [ \"\$(pwd)\" != \"${APP_DIR}\" ]; then
    echo 'FAIL: logs.sh must be executed from /vagrant inside the VM'
    echo \"Current directory: \$(pwd)\"
    echo 'Expected directory: /vagrant'
    echo 'Fix: ensure the repo is mounted correctly and rerun.'
    exit 1
  fi
  echo 'PASS: running from /vagrant'

  if [ ! -f ${COMPOSE_FILE} ]; then
    echo 'FAIL: compose file not found -> ${COMPOSE_FILE}'
    exit 1
  fi

  echo '== streaming compose logs (Ctrl+C to stop) =='
  docker compose -f ${COMPOSE_FILE} logs -f --tail=100
"

echo "== logs: done =="
