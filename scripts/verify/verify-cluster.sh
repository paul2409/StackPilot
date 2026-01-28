#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# scripts/verify/verify-cluster.sh
#
# Verifies VM-to-VM connectivity by HOSTNAME (not IP).
#
# Usage:
#   bash scripts/verify/verify-cluster.sh
# ==========================================================

# ----------------------------------------------------------
# Resolve repo root safely (works from scripts/core/, scripts/verify/, etc.)
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

echo "===== VERIFY CLUSTER (VM to VM by hostname) ====="

cd "$VAGRANT_DIR"

check_resolve() {
  local vm="$1"
  echo "----- $vm: name resolution -----"
  vagrant ssh "$vm" -c "getent hosts control worker1 worker2" >/dev/null 2>&1 \
    && echo "PASS: $vm can resolve all hostnames" \
    || { echo "FAIL: $vm cannot resolve one or more hostnames"; exit 1; }
}

check_ping() {
  local from="$1"
  local to="$2"
  vagrant ssh "$from" -c "ping -c 2 $to" >/dev/null 2>&1 \
    && echo "PASS: $from -> $to" \
    || { echo "FAIL: $from cannot ping $to"; exit 1; }
}

check_resolve control
check_resolve worker1
check_resolve worker2

echo "----- Pings by hostname -----"
check_ping control worker1
check_ping control worker2
check_ping worker1 control
check_ping worker1 worker2
check_ping worker2 control
check_ping worker2 worker1

echo "===== VERIFY CLUSTER: ALL PASS ====="
