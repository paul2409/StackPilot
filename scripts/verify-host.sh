#!/usr/bin/env bash
set -e

VAGRANT_DIR="vagrant"

CONTROL_IP="192.168.56.10"
WORKER1_IP="192.168.56.11"
WORKER2_IP="192.168.56.12"

echo "===== VERIFY HOST ====="

# 1) vagrant exists
if command -v vagrant >/dev/null 2>&1; then
  echo "PASS: vagrant found"
else
  echo "FAIL: vagrant not found"
  exit 1
fi

# 2) vagrant folder exists
if [ -d "$VAGRANT_DIR" ]; then
  echo "PASS: $VAGRANT_DIR folder exists"
else
  echo "FAIL: missing $VAGRANT_DIR folder"
  exit 1
fi

# 3) host can ping IPs
echo "----- Ping VM IPs from HOST -----"
ping -n 2 "$CONTROL_IP" >/dev/null 2>&1 && echo "PASS: ping $CONTROL_IP" || { echo "FAIL: ping $CONTROL_IP"; exit 1; }
ping -n 2 "$WORKER1_IP" >/dev/null 2>&1 && echo "PASS: ping $WORKER1_IP" || { echo "FAIL: ping $WORKER1_IP"; exit 1; }
ping -n 2 "$WORKER2_IP" >/dev/null 2>&1 && echo "PASS: ping $WORKER2_IP" || { echo "FAIL: ping $WORKER2_IP"; exit 1; }

# 4) ssh + hostname check
echo "----- SSH + Hostname -----"
cd "$VAGRANT_DIR"

H=$(vagrant ssh control -c "hostname" 2>/dev/null | tr -d '\r' | tail -n 1)
[ "$H" = "control" ] && echo "PASS: control hostname OK" || { echo "FAIL: control hostname wrong (got: $H)"; exit 1; }

H=$(vagrant ssh worker1 -c "hostname" 2>/dev/null | tr -d '\r' | tail -n 1)
[ "$H" = "worker1" ] && echo "PASS: worker1 hostname OK" || { echo "FAIL: worker1 hostname wrong (got: $H)"; exit 1; }

H=$(vagrant ssh worker2 -c "hostname" 2>/dev/null | tr -d '\r' | tail -n 1)
[ "$H" = "worker2" ] && echo "PASS: worker2 hostname OK" || { echo "FAIL: worker2 hostname wrong (got: $H)"; exit 1; }

echo "===== VERIFY HOST: ALL PASS ====="
