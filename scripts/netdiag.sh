#!/usr/bin/env bash
set -e

echo "===== STACKPILOT NETDIAG ====="
echo "Time:     $(date)"
echo "Host:     $(hostname)"
echo

echo "----- ip a (interfaces) -----"
ip a
echo

echo "----- ip r (routes) -----"
ip r
echo

echo "----- /etc/resolv.conf (DNS config) -----"
cat /etc/resolv.conf
echo

echo "----- ss -lntp (listening TCP ports) -----"
ss -lntp || true
echo

echo "===== END NETDIAG ====="
