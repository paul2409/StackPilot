#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

AWS_ENV_FILE="${ROOT_DIR}/infra/aws/aws.env"
TARGET_ENV_FILE="${ROOT_DIR}/artifacts/aws/target.env"

# shellcheck disable=SC1090
source "$AWS_ENV_FILE"
# shellcheck disable=SC1090
source "$TARGET_ENV_FILE"

: "${TARGET_HOST:?TARGET_HOST missing}"
: "${SSH_USER:?SSH_USER missing}"
: "${SSH_KEY_PATH:?SSH_KEY_PATH missing}"
: "${BASE_URL:?BASE_URL missing}"

REMOTE_DIR="${REMOTE_DIR:-/home/${SSH_USER}/stackpilot}"
COMPOSE_FILE_REL="${COMPOSE_FILE_REL:-infra/docker-compose.yml}"

SSH_OPTS=(
  -i "$SSH_KEY_PATH"
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=10
  -T
)

echo "== DEPLOY =="
echo "host: ${SSH_USER}@${TARGET_HOST}"
echo "remote_dir: ${REMOTE_DIR}"
echo "compose: ${COMPOSE_FILE_REL}"
echo "base_url: ${BASE_URL}"

echo "== SSH preflight =="
ssh "${SSH_OPTS[@]}" "${SSH_USER}@${TARGET_HOST}" "echo ok >/dev/null"

echo "== Upload repo -> EC2 (tar-over-ssh, no rsync) =="

# Excludes (keep aligned with your repo policy)
TAR_EXCLUDES=(
  --exclude=".git"
  --exclude=".terraform"
  --exclude=".vagrant"
  --exclude="artifacts/aws"
  --exclude="ci/logs"
)

# 1) ensure remote dir exists
ssh "${SSH_OPTS[@]}" "${SSH_USER}@${TARGET_HOST}" "mkdir -p '${REMOTE_DIR}'"

# 2) stream tarball over ssh into remote dir
(
  cd "$ROOT_DIR"
  tar -czf - "${TAR_EXCLUDES[@]}" .
) | ssh "${SSH_OPTS[@]}" "${SSH_USER}@${TARGET_HOST}" "tar -xzf - -C '${REMOTE_DIR}'"

echo "== Compose up =="
ssh "${SSH_OPTS[@]}" "${SSH_USER}@${TARGET_HOST}" "bash -lc '
  set -euo pipefail
  cd \"${REMOTE_DIR}\"

  if [[ ! -f \"${COMPOSE_FILE_REL}\" ]]; then
    echo \"FAIL: compose file not found: ${COMPOSE_FILE_REL}\"
    ls -la
    exit 1
  fi

  docker compose -f \"${COMPOSE_FILE_REL}\" up -d --build
  docker compose -f \"${COMPOSE_FILE_REL}\" ps
'"

echo ""
echo "BASE_URL=${BASE_URL}"
echo "Quick checks:"
echo "  curl -fsS \"${BASE_URL}/health\" && echo"
echo "  curl -fsS \"${BASE_URL}/ready\" && echo"
echo "  curl -fsS \"${BASE_URL}/version\" && echo"