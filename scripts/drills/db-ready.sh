#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# scripts/drills/db-ready.sh
#
# Milestone 03 — Phase 2
# Readiness Honesty & Recovery Drill (Host-driven)
#
# WHAT THIS SCRIPT PROVES (END-TO-END):
#
# 1) When the database goes down:
#    - The API stays reachable at the transport layer (TCP)
#    - /health stays 200 (liveness only)
#    - /ready fails (≠ 200) (readiness honesty)
#
# 2) Verification reflects reality:
#    - make verify FAILS during the outage
#
# 3) When the database comes back:
#    - /ready recovers WITHOUT restarting the API
#    - make verify PASSES again
#
# PORTABILITY NOTE (reviewer-friendly):
# - netcat (nc) is preferred but NOT required.
# - TCP reachability is checked using, in order:
#     1) nc        (explicit TCP)
#     2) /dev/tcp  (bash built-in TCP)
#     3) curl      (connect-timeout fallback; weaker but practical)
#
# IMPORTANT DISCIPLINE:
# - Failure is induced via a script (not ad-hoc SSH typing)
# - All validation happens from the HOST
# - SSH is used ONLY to stop/start the DB container
#
# USAGE:
#   bash scripts/drills/db-ready.sh
#   NODE=worker1 bash scripts/drills/db-ready.sh
#   API_PORT=8000 bash scripts/drills/db-ready.sh
# ==========================================================


# ----------------------------------------------------------
# Repo root resolution
#
# Goal:
#   Reliably locate the repository root regardless of where
#   this script lives (scripts/drills/, scripts/core/, etc.)
#
# Strategy:
#   1) Prefer git (most reliable if available)
#   2) Fallback to relative path traversal
# ----------------------------------------------------------

ROOT_DIR=""
if command -v git >/dev/null 2>&1; then
  ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi

if [ -z "${ROOT_DIR:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

VAGRANT_DIR="${ROOT_DIR}/vagrant"


# ----------------------------------------------------------
# Runtime inputs
#
# NODE:
#   Which VM is running the API service. Defaults to "control".
#
# API_PORT:
#   Port exposed by the API service.
# ----------------------------------------------------------

NODE="${NODE:-control}"
API_PORT="${API_PORT:-8000}"


# ----------------------------------------------------------
# Static lab network identity
# ----------------------------------------------------------

CONTROL_IP="192.168.56.10"
WORKER1_IP="192.168.56.11"
WORKER2_IP="192.168.56.12"

case "$NODE" in
  control) SERVICE_IP="$CONTROL_IP" ;;
  worker1) SERVICE_IP="$WORKER1_IP" ;;
  worker2) SERVICE_IP="$WORKER2_IP" ;;
  *)
    echo "FAIL: NODE must be control|worker1|worker2 (got: $NODE)"
    exit 1
    ;;
esac

BASE_URL="http://${SERVICE_IP}:${API_PORT}"


# ----------------------------------------------------------
# Helper functions
# ----------------------------------------------------------

fail() { echo "FAIL: $1"; exit 1; }
pass() { echo "PASS: $1"; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

http_code() {
  curl -sS -o /dev/null -w "%{http_code}" "$1" || echo "000"
}

# ----------------------------------------------------------
# TCP reachability check (portable)
#
# Preferred:
#   nc (netcat) because it is explicit TCP.
#
# Fallbacks:
#   1) bash /dev/tcp (still raw TCP, no extra tools)
#   2) curl --connect-timeout (weaker than raw TCP, but detects
#      transport-level failure quickly in most environments)
# ----------------------------------------------------------
tcp_check() {
  # 1) netcat (best)
  if command -v nc >/dev/null 2>&1; then
    nc -z -w 2 "$SERVICE_IP" "$API_PORT" >/dev/null 2>&1
    return $?
  fi

  # 2) bash built-in TCP socket (no dependencies)
  if (exec 3<>"/dev/tcp/${SERVICE_IP}/${API_PORT}") >/dev/null 2>&1; then
    exec 3>&-
    exec 3<&-
    return 0
  fi

  # 3) curl fallback (least pure but practical)
  if command -v curl >/dev/null 2>&1; then
    curl -sS --connect-timeout 2 -o /dev/null "${BASE_URL}/health" >/dev/null 2>&1
    return $?
  fi

  return 1
}


# ----------------------------------------------------------
# Drill header
# ----------------------------------------------------------

echo "===== MILESTONE 03 — PHASE 2 DRILL ====="
echo "Readiness Honesty & Recovery Proof"
echo "Target NODE: ${NODE}"
echo "Target Service: ${BASE_URL}"
echo


# ----------------------------------------------------------
# Preconditions
#
# Rule:
#   We NEVER run a failure drill on a broken baseline.
# ----------------------------------------------------------

need_cmd vagrant
need_cmd curl

[ -d "$VAGRANT_DIR" ] || fail "missing vagrant directory: $VAGRANT_DIR"

echo "== 0) Baseline check: system must be healthy =="

if ! make -C "$ROOT_DIR" verify; then
  fail "baseline make verify failed — fix baseline before running drill"
fi

pass "baseline verification passes"
echo


# ----------------------------------------------------------
# Step 1: Induce failure
#
# Action:
#   Stop ONLY the database container on the target NODE.
#
# Rule:
#   API container must NOT be restarted.
# ----------------------------------------------------------

echo "== 1) Induce failure: stop DB container only =="

cd "$VAGRANT_DIR"
vagrant ssh "$NODE" -c "bash -lc 'cd /vagrant && docker compose -f infra/docker-compose.yml stop db'"

pass "database container stopped on ${NODE}"
echo


# ----------------------------------------------------------
# Step 2: Prove TCP reachability (transport layer)
# ----------------------------------------------------------

echo "== 2) During outage: TCP must remain reachable =="

if tcp_check; then
  pass "TCP reachable (method: auto) on ${SERVICE_IP}:${API_PORT}"
else
  fail "TCP unreachable while DB down (API should still be reachable)"
fi

echo


# ----------------------------------------------------------
# Step 3: Prove liveness honesty (/health)
# ----------------------------------------------------------

echo "== 3) During outage: /health must stay 200 =="

H_CODE="$(http_code "${BASE_URL}/health")"
[ "$H_CODE" = "200" ] || fail "/health expected 200 during DB outage, got ${H_CODE}"

pass "/health = 200 (liveness preserved)"
echo


# ----------------------------------------------------------
# Step 4: Prove readiness honesty (/ready)
# ----------------------------------------------------------

echo "== 4) During outage: /ready must NOT be 200 =="

R_CODE="$(http_code "${BASE_URL}/ready")"
[ "$R_CODE" != "200" ] || fail "/ready returned 200 while DB down (lying readiness)"

pass "/ready != 200 (got ${R_CODE}) — readiness honesty holds"
echo


# ----------------------------------------------------------
# Step 5: Verification must reflect failure
# ----------------------------------------------------------

echo "== 5) During outage: make verify must FAIL =="

if make -C "$ROOT_DIR" verify; then
  fail "make verify passed during DB outage (verification lying)"
else
  pass "make verify fails during outage (correct)"
fi

echo


# ----------------------------------------------------------
# Step 6: Recover dependency (start DB only)
# ----------------------------------------------------------

echo "== 6) Recover: start DB container =="

cd "$VAGRANT_DIR"
vagrant ssh "$NODE" -c "bash -lc 'cd /vagrant && docker compose -f infra/docker-compose.yml start db'"

pass "database container started on ${NODE}"
echo


# ----------------------------------------------------------
# Step 7: Prove readiness recovery (no API restart)
# ----------------------------------------------------------

echo "== 7) Recovery: wait for /ready to return 200 (max 30s) =="

deadline=$((SECONDS + 30))
while true; do
  code="$(http_code "${BASE_URL}/ready")"
  if [ "$code" = "200" ]; then
    pass "/ready recovered to 200 without API restart"
    break
  fi
  if [ "$SECONDS" -ge "$deadline" ]; then
    fail "/ready did not recover within 30s (last code: ${code})"
  fi
  sleep 2
done

echo


# ----------------------------------------------------------
# Step 8: Verification must pass after recovery
# ----------------------------------------------------------

echo "== 8) Post-recovery: make verify must PASS =="

make -C "$ROOT_DIR" verify >/dev/null 2>&1 \
  || fail "make verify failed after DB recovery"

pass "make verify passes after recovery"
echo


# ----------------------------------------------------------
# Final result
# ----------------------------------------------------------

echo "===== DRILL PASS ====="
echo "Readiness honesty, failure behavior, and recovery proven"
echo "Milestone 03 — Phase 2 COMPLETE"