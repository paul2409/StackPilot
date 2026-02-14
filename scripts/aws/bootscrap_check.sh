#!/usr/bin/env bash
set -euo pipefail

# scripts/aws/bootstrap_check.sh
# Verifies EC2 host is Docker-ready.
# Uses sudo for docker commands to avoid "docker.sock permission" issues during bootstrap.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

AWS_ENV="${ROOT_DIR}/infra/aws/aws.env"
TARGET_ENV="${ROOT_DIR}/artifacts/aws/target.env"

if [[ -f "${AWS_ENV}" ]]; then
  # shellcheck disable=SC1090
  source "${AWS_ENV}"
fi

if [[ ! -f "${TARGET_ENV}" ]]; then
  echo "FAIL: missing ${TARGET_ENV}"
  echo "Run your target env generator first (e.g. scripts/aws/target-env.sh)"
  exit 1
fi

# shellcheck disable=SC1090
source "${TARGET_ENV}"

: "${TARGET_HOST:?TARGET_HOST not set in target.env}"
: "${SSH_USER:=ubuntu}"
: "${SSH_KEY_PATH:?SSH_KEY_PATH not set (set in aws.env or target.env)}"

echo "== BOOTSTRAP CHECK =="
echo "TARGET_HOST=${TARGET_HOST}"
echo "SSH_USER=${SSH_USER}"
echo "SSH_KEY_PATH=${SSH_KEY_PATH}"

SSH_OPTS=(
  -i "${SSH_KEY_PATH}"
  -o StrictHostKeyChecking=accept-new
  -o ConnectTimeout=10
)

echo "== waiting for ssh =="
for i in {1..30}; do
  if ssh "${SSH_OPTS[@]}" "${SSH_USER}@${TARGET_HOST}" "echo SSH_OK" >/dev/null 2>&1; then
    echo "SSH ok"
    break
  fi
  sleep 2
  if [[ "${i}" == "30" ]]; then
    echo "FAIL: SSH never became ready"
    exit 1
  fi
done

echo "== docker daemon status =="
ssh "${SSH_OPTS[@]}" "${SSH_USER}@${TARGET_HOST}" "sudo systemctl is-active docker >/dev/null && echo docker_active || (echo docker_not_active; sudo systemctl status docker --no-pager; exit 1)"

echo "== docker version =="
ssh "${SSH_OPTS[@]}" "${SSH_USER}@${TARGET_HOST}" "sudo docker version"

echo "== docker compose version =="
ssh "${SSH_OPTS[@]}" "${SSH_USER}@${TARGET_HOST}" "sudo docker compose version"

echo "== hello-world =="
ssh "${SSH_OPTS[@]}" "${SSH_USER}@${TARGET_HOST}" "sudo docker run --rm hello-world >/dev/null && echo hello_world_ok"

echo "PASS: bootstrap_check"