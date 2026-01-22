#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# verify-host.sh
#
# This script verifies the system from the HOST machine.
# It proves:
# 1) The lab is reachable and correctly identified
# 2) The service is reachable, honest about readiness,
#    and exposes version information
#
# Readiness expectation:
#   EXPECT_READY=up   -> dependencies working, /ready MUST be 200
#   EXPECT_READY=down -> dependency unavailable, /ready MUST NOT be 200
#
# Default assumes dependencies are working.
# ============================================================

# ------------------------------------------------------------
# Resolve project paths
# ------------------------------------------------------------
# ROOT_DIR    -> project root (one level above scripts/)
# VAGRANT_DIR -> location of Vagrantfile
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAGRANT_DIR="$ROOT_DIR/vagrant"

# ------------------------------------------------------------
# Static VM network identity
# ------------------------------------------------------------
# These IPs are fixed by design and verified below
CONTROL_IP="192.168.56.10"
WORKER1_IP="192.168.56.11"
WORKER2_IP="192.168.56.12"
SERVICE_IP="${SERVICE_IP:-$CONTROL_IP}"

# ------------------------------------------------------------
# Service access configuration
# ------------------------------------------------------------
# API is exposed from the control VM to the host
API_PORT="${API_PORT:-8000}"
BASE_URL="http://${SERVICE_IP}:${API_PORT}"

# ------------------------------------------------------------
# Small helpers for consistent output
# ------------------------------------------------------------
fail(){ echo "FAIL: $1"; exit 1; }
pass(){ echo "PASS: $1"; }

# ------------------------------------------------------------
# Cross-platform ping handling
# ------------------------------------------------------------
# Linux/macOS use -c, Windows uses -n
PING_FLAG="-c"
ping -n 1 127.0.0.1 >/dev/null 2>&1 && PING_FLAG="-n"

# ------------------------------------------------------------
# Helper to fetch HTTP status codes quietly
# ------------------------------------------------------------
http_code() {
  curl -sS -o /dev/null -w "%{http_code}" "$1" || echo "000"
}

echo "===== VERIFY HOST ====="

# ------------------------------------------------------------
# Tooling sanity: vagrant must exist
# ------------------------------------------------------------
command -v vagrant >/dev/null 2>&1 || fail "vagrant not installed"
pass "vagrant installed"

# ------------------------------------------------------------
# Repo structure sanity: vagrant directory must exist
# ------------------------------------------------------------
[ -d "$VAGRANT_DIR" ] || fail "missing vagrant directory"
pass "vagrant directory present"

# ------------------------------------------------------------
# Host-to-VM network reachability
# ------------------------------------------------------------
# Proves the host can reach all nodes by IP
ping "$PING_FLAG" 2 "$CONTROL_IP" >/dev/null 2>&1 || fail "cannot ping control VM"
ping "$PING_FLAG" 2 "$WORKER1_IP" >/dev/null 2>&1 || fail "cannot ping worker1 VM"
ping "$PING_FLAG" 2 "$WORKER2_IP" >/dev/null 2>&1 || fail "cannot ping worker2 VM"
pass "all VMs reachable from host"

# ------------------------------------------------------------
# SSH access + hostname identity
# ------------------------------------------------------------
# Ensures each VM reports the correct hostname
cd "$VAGRANT_DIR"

H=$(vagrant ssh control -c "hostname" 2>/dev/null | tr -d '\r' | tail -n 1)
[ "$H" = "control" ] || fail "control hostname mismatch (got: $H)"

H=$(vagrant ssh worker1 -c "hostname" 2>/dev/null | tr -d '\r' | tail -n 1)
[ "$H" = "worker1" ] || fail "worker1 hostname mismatch (got: $H)"

H=$(vagrant ssh worker2 -c "hostname" 2>/dev/null | tr -d '\r' | tail -n 1)
[ "$H" = "worker2" ] || fail "worker2 hostname mismatch (got: $H)"

pass "SSH access and hostnames verified"

# ------------------------------------------------------------
# Service liveness (host perspective)
# ------------------------------------------------------------
# Confirms the service process is reachable from the host
command -v curl >/dev/null 2>&1 || fail "curl not installed"
command -v jq   >/dev/null 2>&1 || fail "jq not installed"

[ "$(http_code "$BASE_URL/health")" = "200" ] \
  || fail "service not reachable from host (/health)"
pass "service reachable from host"

# ------------------------------------------------------------
# Service readiness (dependency-aware)
# ------------------------------------------------------------
# EXPECT_READY=up   -> /ready MUST return 200
# EXPECT_READY=down -> /ready MUST NOT return 200
EXPECT_READY="${EXPECT_READY:-up}"
READY_CODE="$(http_code "$BASE_URL/ready")"

if [[ "$EXPECT_READY" = "up" ]]; then
  [ "$READY_CODE" = "200" ] \
    || fail "service not ready but should be (got $READY_CODE)"
  pass "service ready (dependencies OK)"
else
  [ "$READY_CODE" != "200" ] \
    || fail "service reports ready but dependency expected down"
  pass "service correctly reports not ready"
fi

# ------------------------------------------------------------
# Version transparency
# ------------------------------------------------------------
# Confirms build/version info is exposed and structured
VERSION_JSON="$(curl -sS "$BASE_URL/version" || true)"
echo "$VERSION_JSON" | jq -e . >/dev/null 2>&1 \
  || fail "version endpoint not valid JSON"
echo "$VERSION_JSON" | jq -e 'has("service") and has("version")' >/dev/null 2>&1 \
  || fail "version endpoint missing fields (service, version)"
pass "service version information exposed"

echo "===== VERIFY HOST: ALL PASS ====="
echo "Target service at $BASE_URL verified successfully from host."
