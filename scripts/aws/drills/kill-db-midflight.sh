#!/usr/bin/env bash
set -euo pipefail

# DB-stop readiness drill for StackPilot
# Proves:
# - /health stays 200 even when DB is down
# - /ready becomes 503 when DB is down, then returns 200 after recovery
# - /order returns 503 (not 500) when DB is down, then works after recovery

# ---------- config ----------
# --- auto-load env files (no manual export required) ---
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"

if [ -f "$ROOT_DIR/infra/aws/aws.env" ]; then
  set -a
  source "$ROOT_DIR/infra/aws/aws.env"
  set +a
fi

if [ -f "$ROOT_DIR/artifacts/aws/target.env" ]; then
  set -a
  source "$ROOT_DIR/artifacts/aws/target.env"
  set +a
fi
: "${BASE_URL:?BASE_URL is required (e.g. http://1.2.3.4:8000)}"
: "${TARGET_HOST:=}"
: "${SSH_USER:=ubuntu}"
: "${SSH_KEY_PATH:=}"
: "${COMPOSE_FILE:=infra/docker-compose.yml}"
: "${DB_SERVICE:=db}"
: "${API_SERVICE:=api}"
: "${DRILL_TIMEOUT_SECS:=45}"

# ---------- helpers ----------
ts() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
log() { echo "[$(ts)] $*"; }

curl_code() {
  # prints: "<http_code>"
  curl -sS -o /dev/null -w "%{http_code}" "$1" || echo "000"
}

require_ssh() {
  if [[ -z "${TARGET_HOST}" || -z "${SSH_KEY_PATH}" ]]; then
    log "No TARGET_HOST/SSH_KEY_PATH provided, assuming you're running locally."
    return 1
  fi
  return 0
}

remote() {
  # Run a command on the EC2 host
  ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 \
    "$SSH_USER@$TARGET_HOST" "$@"
}

compose_down_db() {
  if require_ssh; then
    remote "cd ~/stackpilot && docker compose -f ${COMPOSE_FILE} stop ${DB_SERVICE}"
  else
    docker compose -f "${COMPOSE_FILE}" stop "${DB_SERVICE}"
  fi
}

compose_up_db() {
  if require_ssh; then
    remote "cd ~/stackpilot && docker compose -f ${COMPOSE_FILE} up -d ${DB_SERVICE}"
  else
    docker compose -f "${COMPOSE_FILE}" up -d "${DB_SERVICE}"
  fi
}

wait_http() {
  local url="$1"
  local want="$2"
  local deadline=$(( $(date +%s) + DRILL_TIMEOUT_SECS ))

  while true; do
    local got
    got="$(curl_code "$url")"
    if [[ "$got" == "$want" ]]; then
      echo "$got"
      return 0
    fi
    if [[ $(date +%s) -ge $deadline ]]; then
      log "Timeout waiting for $url to return $want (last=$got)"
      return 1
    fi
    sleep 1
  done
}

assert_code() {
  local label="$1"
  local url="$2"
  local want="$3"

  local got
  got="$(curl_code "$url")"
  if [[ "$got" != "$want" ]]; then
    log "FAIL: $label expected $want got $got ($url)"
    return 1
  fi
  log "OK:   $label -> $got"
}

post_order_code() {
  # returns http code for a POST /order
  curl -sS -o /dev/null -w "%{http_code}" -X POST \
    "${BASE_URL}/order?symbol=BTC&side=buy&qty=1" || echo "000"
}

assert_post_order_code() {
  local label="$1"
  local want="$2"
  local got
  got="$(post_order_code)"
  if [[ "$got" != "$want" ]]; then
    log "FAIL: $label expected $want got $got (POST ${BASE_URL}/order...)"
    return 1
  fi
  log "OK:   $label -> $got"
}

# ---------- drill ----------
log "DB-stop readiness drill starting"
log "BASE_URL=${BASE_URL}"

# 0) baseline checks
assert_code "baseline /health"  "${BASE_URL}/health"  "200"
assert_code "baseline /ready"   "${BASE_URL}/ready"   "200"
assert_code "baseline /version" "${BASE_URL}/version" "200"

# 1) stop DB
log "Stopping DB service (${DB_SERVICE})"
compose_down_db

# 2) prove health stays 200
assert_code "DB down /health (must stay 200)" "${BASE_URL}/health" "200"

# 3) readiness flips to 503
log "Waiting for /ready to flip to 503"
wait_http "${BASE_URL}/ready" "503" >/dev/null
assert_code "DB down /ready (must be 503)" "${BASE_URL}/ready" "503"

# 4) order should fail as 503 (NOT 500)
# If your API currently returns 500 on DB failure, you need to fix db_connect() to raise 503.
assert_post_order_code "DB down POST /order (must be 503)" "503"

# 5) start DB again
log "Starting DB service (${DB_SERVICE})"
compose_up_db

# 6) wait for readiness to come back
log "Waiting for /ready to recover to 200"
wait_http "${BASE_URL}/ready" "200" >/dev/null
assert_code "DB recovered /ready" "${BASE_URL}/ready" "200"

# 7) order should work again (200)
# Your /order returns JSON; it should be 200 on success.
assert_post_order_code "DB recovered POST /order (must be 200)" "200"

log "PASS: DB-stop readiness drill complete"