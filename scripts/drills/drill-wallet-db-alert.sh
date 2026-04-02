#!/usr/bin/env bash
set -euo pipefail

APP_NS="${APP_NS:-stackpilot-dev}"

kubectl -n "${APP_NS}" scale deployment postgres-wallet --replicas=0
sleep 15

kubectl -n "${APP_NS}" port-forward svc/wallet-service 18080:8000 >/tmp/stackpilot-wallet-pf.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT
sleep 3

echo "wallet /health"
curl -sS http://127.0.0.1:18080/health || true
echo
echo "wallet /ready"
curl -sS http://127.0.0.1:18080/ready || true
echo
echo "wallet /metrics snippet"
curl -sS http://127.0.0.1:18080/metrics | grep -E 'wallet_db_check_failures_total|wallet_dependency_state|service_ready_state' || true
echo

kill ${PF_PID} >/dev/null 2>&1 || true
trap - EXIT

kubectl -n "${APP_NS}" scale deployment postgres-wallet --replicas=1
kubectl -n "${APP_NS}" rollout status deployment/postgres-wallet --timeout=180s >/dev/null

echo "PASS: wallet DB drill completed"
