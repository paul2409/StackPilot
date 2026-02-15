#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load AWS environment (contains SSH_KEY_PATH, SSH_USER, etc.)
if [[ -f "$ROOT_DIR/infra/aws/aws.env" ]]; then
  set -a
  source "$ROOT_DIR/infra/aws/aws.env"
  set +a
else
  echo "ERROR: infra/aws/aws.env not found"
  exit 1
fi

# Load deployment target
if [[ -f "$ROOT_DIR/artifacts/aws/target.env" ]]; then
  set -a
  source "$ROOT_DIR/artifacts/aws/target.env"
  set +a
else
  echo "ERROR: artifacts/aws/target.env not found"
  exit 1
fi

log() { printf "[deploy-aws] %s\n" "$*"; }
die() { printf "[deploy-aws] FAIL: %s\n" "$*" >&2; exit 1; }

require() {
  local name="$1"
  [[ -n "${!name:-}" ]] || die "$name missing"
}

# --- Load target.env if present (preferred) ---
if [[ -f "artifacts/aws/target.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source "artifacts/aws/target.env"
  set +a
fi

# --- Required inputs ---
require SSH_KEY_PATH
require SSH_USER
require TARGET_HOST

# Optional, but commonly used
API_PORT="${API_PORT:-8000}"

REMOTE_BASE="/home/${SSH_USER}"
REMOTE_DIR="${REMOTE_BASE}/stackpilot"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
ARCHIVE="stackpilot-${STAMP}.tar.gz"
LOCAL_TMP_DIR="artifacts/aws/run"
LOCAL_ARCHIVE_PATH="${LOCAL_TMP_DIR}/${ARCHIVE}"
REMOTE_ARCHIVE_PATH="${REMOTE_BASE}/${ARCHIVE}"

mkdir -p "${LOCAL_TMP_DIR}"

log "starting deploy"
log "target: ${SSH_USER}@${TARGET_HOST}"
log "remote dir: ${REMOTE_DIR}"
log "api port: ${API_PORT}"
log ""

# --- Build archive (explicit excludes to avoid shipping junk) ---
log "COPY START: packaging repo -> ${LOCAL_ARCHIVE_PATH}"

tar \
  --exclude=".git" \
  --exclude=".venv" \
  --exclude="venv" \
  --exclude="__pycache__" \
  --exclude=".pytest_cache" \
  --exclude=".mypy_cache" \
  --exclude=".terraform" \
  --exclude="infra/aws/tf/.terraform" \
  --exclude="artifacts" \
  --exclude="node_modules" \
  --exclude="*.pyc" \
  --exclude="*.log" \
  -czf "${LOCAL_ARCHIVE_PATH}" .

log "COPY MID: archive created ($(wc -c < "${LOCAL_ARCHIVE_PATH}" | tr -d ' ') bytes)"
log "COPY END: packaging complete"
log ""

# --- Transfer archive ---
log "COPY START: uploading archive -> ${REMOTE_ARCHIVE_PATH}"
scp -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${LOCAL_ARCHIVE_PATH}" "${SSH_USER}@${TARGET_HOST}:${REMOTE_ARCHIVE_PATH}"
log "COPY END: upload complete"
log ""

# --- Extract on remote and deploy containers ---
log "REMOTE START: extract + deploy"
ssh -i "${SSH_KEY_PATH}" -o StrictHostKeyChecking=no "${SSH_USER}@${TARGET_HOST}" "bash -lc '
set -euo pipefail

echo \"[remote] ensuring ${REMOTE_DIR}\"
mkdir -p \"${REMOTE_DIR}\"

echo \"[remote] extracting ${REMOTE_ARCHIVE_PATH} -> ${REMOTE_DIR}\"
tar -xzf \"${REMOTE_ARCHIVE_PATH}\" -C \"${REMOTE_DIR}\"

echo \"[remote] cleanup archive\"
rm -f \"${REMOTE_ARCHIVE_PATH}\"

cd \"${REMOTE_DIR}\"

echo \"[remote] docker compose up (build api)\"
docker compose -f infra/docker-compose.yml up -d --build api db

echo \"[remote] quick status\"
docker compose -f infra/docker-compose.yml ps
'"

log "REMOTE END: extract + deploy complete"
log ""

log "PASS: deploy complete"
log "tip: run: make verify-aws"