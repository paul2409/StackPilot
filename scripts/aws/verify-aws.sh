#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load env (no manual exports needed)
set -a
source "$ROOT_DIR/infra/aws/aws.env"
source "$ROOT_DIR/artifacts/aws/target.env"
set +a

: "${SSH_USER:?missing SSH_USER in infra/aws/aws.env}"
: "${SSH_KEY_PATH:?missing SSH_KEY_PATH in infra/aws/aws.env}"
: "${TARGET_HOST:?missing TARGET_HOST in artifacts/aws/target.env}"
: "${API_PORT:?missing API_PORT in artifacts/aws/target.env}"
: "${BASE_URL:?missing BASE_URL in artifacts/aws/target.env}"

REMOTE_DIR="/home/${SSH_USER}/stackpilot"
COMPOSE_FILE="infra/docker-compose.yml"

# Your schema file INSIDE the repo on the EC2 box
SCHEMA_HOST_PATH="$REMOTE_DIR/infra/db/init/001_schema.sql"
# Where we put it INSIDE the db container
SCHEMA_CONTAINER_PATH="/tmp/001_schema.sql"

ART_DIR="$ROOT_DIR/artifacts/logs/aws"
REMOTE_LOG_FILE="${ART_DIR}/remote-docker.log"

fail() { echo "FAIL: $*" >&2; collect_remote_logs || true; exit 1; }
pass() { echo "PASS: $*"; }

collect_remote_logs() {
  mkdir -p "${ART_DIR}"
  echo "== collecting remote docker logs ==" | tee "${REMOTE_LOG_FILE}" >/dev/null

  ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$SSH_USER@$TARGET_HOST" "bash -lc '
set -euo pipefail
cd \"${REMOTE_DIR}\" 2>/dev/null || true

echo \"=== date ===\"
date || true
echo

echo \"=== whoami ===\"
whoami || true
echo

echo \"=== docker ps ===\"
sudo docker ps || true
echo

echo \"=== docker compose ps ===\"
sudo docker compose -f \"${COMPOSE_FILE}\" ps || true
echo

echo \"=== docker compose logs (tail) ===\"
sudo docker compose -f \"${COMPOSE_FILE}\" logs --no-color --tail=400 || true
echo

echo \"=== journalctl docker (tail) ===\"
sudo journalctl -u docker --no-pager -n 200 || true
'" >> "${REMOTE_LOG_FILE}" 2>&1 || true

  echo "== remote logs saved: ${REMOTE_LOG_FILE} ==" >> "${REMOTE_LOG_FILE}" 2>/dev/null || true
}

echo "== target =="
echo "BASE_URL=$BASE_URL"
echo "TARGET_HOST=$TARGET_HOST"
echo "API_PORT=$API_PORT"

echo "== tcp check =="
# Use bash /dev/tcp on your local machine (works in Git Bash/WSL; if it fails there, the script will show it)
if ! timeout 5 bash -c "cat < /dev/null > /dev/tcp/${TARGET_HOST}/${API_PORT}" 2>/dev/null; then
  fail "tcp unreachable ${TARGET_HOST}:${API_PORT} (check SG, IP change, instance listening)"
fi
pass "tcp reachable"

echo "== ensure schema (idempotent) =="
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$SSH_USER@$TARGET_HOST" "bash -lc '
set -euo pipefail
cd \"${REMOTE_DIR}\"

test -f \"${SCHEMA_HOST_PATH}\" || { echo \"schema file missing at ${SCHEMA_HOST_PATH}\"; exit 2; }

# copy schema into db container
sudo docker compose -f \"${COMPOSE_FILE}\" cp \"${SCHEMA_HOST_PATH}\" db:\"${SCHEMA_CONTAINER_PATH}\"

# apply schema (safe to re-run if SQL uses IF NOT EXISTS / or create table guarded)
sudo docker compose -f \"${COMPOSE_FILE}\" exec -T db \
  psql -U stackpilot -d stackpilot -v ON_ERROR_STOP=1 -f \"${SCHEMA_CONTAINER_PATH}\"

# prove tables exist
sudo docker compose -f \"${COMPOSE_FILE}\" exec -T db \
  psql -U stackpilot -d stackpilot -v ON_ERROR_STOP=1 -c \"\\dt public.*\"
'" || fail "schema ensure failed"
pass "schema ensured"

echo "== http checks =="
curl -fsS --max-time 5 "$BASE_URL/health" >/dev/null || fail "/health failed"
pass "/health ok"

curl -fsS --max-time 5 "$BASE_URL/version" >/dev/null || fail "/version failed"
pass "/version ok"

# /ready should be OK when db is healthy
curl -fsS --max-time 5 "$BASE_URL/ready" >/dev/null || fail "/ready failed"
pass "/ready ok"

echo "== persistence check =="
ORDER_ID="$(curl -fsS --max-time 10 -X POST "$BASE_URL/order?symbol=BTC&side=buy&qty=1" \
  | python -c "import sys,json; print(json.load(sys.stdin).get('order_id',''))")"
test -n "$ORDER_ID" || fail "order_id missing"
pass "order created id=$ORDER_ID"

# restart API container and ensure order still exists
ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$SSH_USER@$TARGET_HOST" "bash -lc '
set -euo pipefail
cd \"${REMOTE_DIR}\"
sudo docker compose -f \"${COMPOSE_FILE}\" restart api
'" || fail "api restart failed"
pass "api restarted"

curl -fsS --max-time 10 "$BASE_URL/orders/$ORDER_ID" >/dev/null || fail "order fetch failed after restart"
pass "persistence ok"

echo "PASS: verify-aws"
