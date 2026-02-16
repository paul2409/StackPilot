#!/usr/bin/env bash
# scripts/aws/verify-aws.sh
# Phase 4 (simple but complete):
# - tcp reachable
# - /health OK
# - /ready OK
# - ensure schema (idempotent) BEFORE order write/read
# - create order -> fetch order
# - restart api -> health/ready OK -> fetch same order again
# - collect remote docker/compose logs into artifacts (on fail + on pass)

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load env (no manual exports)
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

# Adjust if your compose uses different creds
DB_USER="${DB_USER:-stackpilot}"
DB_NAME="${DB_NAME:-stackpilot}"

HEALTH_URL="${BASE_URL%/}/health"
READY_URL="${BASE_URL%/}/ready"
ORDER_POST_URL="${BASE_URL%/}/order?symbol=BTC&side=buy&qty=1"

# Schema file in repo on EC2
SCHEMA_HOST_PATH="${REMOTE_DIR}/infra/db/init/001_schema.sql"
SCHEMA_CONTAINER_PATH="/tmp/001_schema.sql"

LOG_DIR="${ROOT_DIR}/artifacts/logs/aws/remote"
mkdir -p "$LOG_DIR"

DEADLINE_SEC="${VERIFY_DEADLINE_SEC:-180}"
INTERVAL_SEC="${VERIFY_INTERVAL_SEC:-5}"

log()  { printf "[verify-aws] %s\n" "$*"; }
fail() { printf "[verify-aws] FAIL: %s\n" "$*" >&2; collect_logs || true; exit 1; }

ssh_remote() {
  ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$SSH_USER@$TARGET_HOST" "bash -lc '$*'"
}

collect_logs() {
  log "LOGS: collecting into $LOG_DIR"

  ssh_remote "cd '$REMOTE_DIR' && docker compose -f '$COMPOSE_FILE' ps" \
    > "$LOG_DIR/compose-ps.txt" 2>&1 || true

  ssh_remote "cd '$REMOTE_DIR' && docker compose -f '$COMPOSE_FILE' logs --no-color --timestamps --tail=400" \
    > "$LOG_DIR/compose-logs.txt" 2>&1 || true

  ssh_remote "docker info" > "$LOG_DIR/docker-info.txt" 2>&1 || true

  log "LOGS: done"
}

poll_ok() {
  local url="$1"
  local name="$2"
  local elapsed=0

  log "POLL: $name -> $url (deadline=${DEADLINE_SEC}s)"
  while true; do
    if curl -fsS --max-time 5 "$url" >/dev/null 2>&1; then
      log "POLL: OK ($name) after ${elapsed}s"
      return 0
    fi

    sleep "$INTERVAL_SEC"
    elapsed=$((elapsed + INTERVAL_SEC))
    if [[ "$elapsed" -ge "$DEADLINE_SEC" ]]; then
      return 1
    fi
  done
}

ensure_schema() {
  log "SCHEMA: ensure (idempotent)"

  ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$SSH_USER@$TARGET_HOST" <<EOF
set -euo pipefail

cd "$REMOTE_DIR"

if [ ! -f "$SCHEMA_HOST_PATH" ]; then
  echo "missing schema file: $SCHEMA_HOST_PATH"
  exit 2
fi

docker compose -f "$COMPOSE_FILE" cp "$SCHEMA_HOST_PATH" db:$SCHEMA_CONTAINER_PATH

docker compose -f "$COMPOSE_FILE" exec -T db \
  psql -U "$DB_USER" -d "$DB_NAME" -v ON_ERROR_STOP=1 -f "$SCHEMA_CONTAINER_PATH"

EOF
}

create_order_id() {
  local resp
  resp="$(curl -fsS --max-time 10 -X POST "$ORDER_POST_URL" || true)"
  [[ -n "$resp" ]] || return 1

  if command -v python >/dev/null 2>&1; then
    printf '%s' "$resp" | python -c "import sys,json; print(json.load(sys.stdin).get('order_id',''))"
    return 0
  fi

  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$resp" | jq -r '.order_id // empty'
    return 0
  fi

  return 1
}

# ---------------------------
# Start checks
# ---------------------------
log "target: $SSH_USER@$TARGET_HOST"
log "BASE_URL=$BASE_URL"
log "api port=$API_PORT"
log ""

log "CHECK: tcp reachable"
if ! timeout 5 bash -c "cat < /dev/null > /dev/tcp/${TARGET_HOST}/${API_PORT}" 2>/dev/null; then
  fail "tcp unreachable ${TARGET_HOST}:${API_PORT}"
fi

log "CHECK: /health"
poll_ok "$HEALTH_URL" "/health" || fail "/health timeout"

log "CHECK: /ready"
poll_ok "$READY_URL" "/ready" || fail "/ready timeout"

log "CHECK: schema before DB proof"
ensure_schema || fail "schema ensure failed"

log "CHECK: DB write/read proof"
ORDER_ID="$(create_order_id || true)"
[[ -n "${ORDER_ID:-}" ]] || fail "order_id missing from POST /order"
curl -fsS --max-time 10 "${BASE_URL%/}/orders/${ORDER_ID}" >/dev/null || fail "GET /orders/${ORDER_ID} failed"
log "OK: order created+read id=$ORDER_ID"

log "CHECK: restart api -> recover"
ssh_remote "cd '$REMOTE_DIR' && docker compose -f '$COMPOSE_FILE' restart api" || fail "api restart failed"
poll_ok "$HEALTH_URL" "health after restart" || fail "/health not OK after restart"
poll_ok "$READY_URL" "ready after restart" || fail "/ready not OK after restart"

log "CHECK: persistence after restart"
curl -fsS --max-time 10 "${BASE_URL%/}/orders/${ORDER_ID}" >/dev/null || fail "order missing after restart"
log "OK: persistence confirmed"

collect_logs || true
log "PASS: verify-aws"