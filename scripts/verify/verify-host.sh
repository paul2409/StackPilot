#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# scripts/verify/verify-host.sh
#
# Verifies the system from the HOST machine.
#
# Readiness expectation:
#   EXPECT_READY=up   -> /ready MUST be 200
#   EXPECT_READY=down -> /ready MUST NOT be 200
#
# Usage:
#   bash scripts/verify/verify-host.sh
#   SERVICE_IP=192.168.56.11 bash scripts/verify/verify-host.sh
# ============================================================

# ------------------------------------------------------------
# Resolve repo root safely (works from scripts/core/, scripts/verify/, etc.)
# ------------------------------------------------------------
ROOT_DIR=""
if command -v git >/dev/null 2>&1; then
  ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "${ROOT_DIR:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

VAGRANT_DIR="${ROOT_DIR}/vagrant"

# ------------------------------------------------------------
# Static VM network identity
# ------------------------------------------------------------
CONTROL_IP="192.168.56.10"
WORKER1_IP="192.168.56.11"
WORKER2_IP="192.168.56.12"
SERVICE_IP="${SERVICE_IP:-$CONTROL_IP}"

# ------------------------------------------------------------
# Service access configuration
# ------------------------------------------------------------
API_PORT="${API_PORT:-8000}"
BASE_URL="http://${SERVICE_IP}:${API_PORT}"

fail(){ echo "FAIL: $1"; exit 1; }
pass(){ echo "PASS: $1"; }

# Cross-platform ping handling
PING_FLAG="-c"
ping -n 1 127.0.0.1 >/dev/null 2>&1 && PING_FLAG="-n"

http_code() {
  curl -sS -o /dev/null -w "%{http_code}" "$1" || echo "000"
}

echo "===== VERIFY HOST ====="

command -v vagrant >/dev/null 2>&1 || fail "vagrant not installed"
pass "vagrant installed"

[ -d "$VAGRANT_DIR" ] || fail "missing vagrant directory"
pass "vagrant directory present"

ping "$PING_FLAG" 2 "$CONTROL_IP" >/dev/null 2>&1 || fail "cannot ping control VM"
ping "$PING_FLAG" 2 "$WORKER1_IP" >/dev/null 2>&1 || fail "cannot ping worker1 VM"
ping "$PING_FLAG" 2 "$WORKER2_IP" >/dev/null 2>&1 || fail "cannot ping worker2 VM"
pass "all VMs reachable from host"

cd "$VAGRANT_DIR"

H=$(vagrant ssh control -c "hostname" 2>/dev/null | tr -d '\r' | tail -n 1)
[ "$H" = "control" ] || fail "control hostname mismatch (got: $H)"

H=$(vagrant ssh worker1 -c "hostname" 2>/dev/null | tr -d '\r' | tail -n 1)
[ "$H" = "worker1" ] || fail "worker1 hostname mismatch (got: $H)"

H=$(vagrant ssh worker2 -c "hostname" 2>/dev/null | tr -d '\r' | tail -n 1)
[ "$H" = "worker2" ] || fail "worker2 hostname mismatch (got: $H)"

pass "SSH access and hostnames verified"

command -v curl >/dev/null 2>&1 || fail "curl not installed"
command -v jq   >/dev/null 2>&1 || fail "jq not installed"

[ "$(http_code "$BASE_URL/health")" = "200" ] || fail "service not reachable from host (/health)"
pass "service reachable from host"

EXPECT_READY="${EXPECT_READY:-up}"
READY_CODE="$(http_code "$BASE_URL/ready")"

if [[ "$EXPECT_READY" = "up" ]]; then
  [ "$READY_CODE" = "200" ] || fail "service not ready but should be (got $READY_CODE)"
  pass "service ready (dependencies OK)"
else
  [ "$READY_CODE" != "200" ] || fail "service reports ready but dependency expected down"
  pass "service correctly reports not ready"
fi

VERSION_JSON="$(curl -sS "$BASE_URL/version" || true)"
echo "$VERSION_JSON" | jq -e . >/dev/null 2>&1 || fail "version endpoint not valid JSON"
echo "$VERSION_JSON" | jq -e 'has("service") and has("version")' >/dev/null 2>&1 \
  || fail "version endpoint missing fields (service, version)"
pass "service version information exposed"

echo "===== VERIFY HOST: ALL PASS ====="
echo "Target service at $BASE_URL verified successfully from host."
