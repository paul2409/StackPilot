#!/usr/bin/env bash
set -euo pipefail
CONTROL_HOST="${CONTROL_HOST:-control}"

echo "[k3s] nodes:"
ssh "${CONTROL_HOST}" "sudo kubectl get nodes -o wide"

echo
echo "[k3s] kube-system pods:"
ssh "${CONTROL_HOST}" "sudo kubectl get pods -n kube-system -o wide"
