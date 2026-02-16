#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load AWS env
if [[ -f "$ROOT_DIR/infra/aws/aws.env" ]]; then
  set -a
  source "$ROOT_DIR/infra/aws/aws.env"
  set +a
else
  echo "ERROR: infra/aws/aws.env not found"
  exit 1
fi

# Load target
if [[ -f "$ROOT_DIR/artifacts/aws/target.env" ]]; then
  set -a
  source "$ROOT_DIR/artifacts/aws/target.env"
  set +a
else
  echo "ERROR: artifacts/aws/target.env not found"
  exit 1
fi

log() { printf "[remote-logs] %s\n" "$*"; }
die() { printf "[remote-logs] FAIL: %s\n" "$*" >&2; exit 1; }

require() { local n="$1"; [[ -n "${!n:-}" ]] || die "$n missing"; }

require SSH_KEY_PATH
require SSH_USER
require TARGET_HOST

REMOTE_DIR="/home/${SSH_USER}/stackpilot"
OUT_DIR="$ROOT_DIR/artifacts/logs/aws"
mkdir -p "${OUT_DIR}"

log "collecting remote docker logs from ${SSH_USER}@${TARGET_HOST}"
log "saving under: ${OUT_DIR}"

ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${SSH_USER}@${TARGET_HOST}" "bash -lc '
set -euo pipefail
cd \"${REMOTE_DIR}\" || exit 0

echo \"=== docker ps ===\"
sudo docker ps || true
echo

echo \"=== docker compose ps ===\"
sudo docker compose -f infra/docker-compose.yml ps || true
echo

echo \"=== docker compose logs (tail) ===\"
sudo docker compose -f infra/docker-compose.yml logs --no-color --tail=400 || true
echo

echo \"=== journalctl docker (tail) ===\"
sudo journalctl -u docker --no-pager -n 200 || true
'" > "${OUT_DIR}/remote-docker.log" 2>&1 || true

log "done: ${OUT_DIR}/remote-docker.log"
