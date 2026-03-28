#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-stackpilot}"

echo "=== Verifying deployments ==="
kubectl get deployments -n "${NAMESPACE}"

echo
echo "=== Verifying pods ==="
kubectl get pods -n "${NAMESPACE}"

echo
echo "=== Verifying services ==="
kubectl get svc -n "${NAMESPACE}"

echo
echo "=== Verifying ingress ==="
kubectl get ingress -n "${NAMESPACE}"

echo
echo "=== Verifying endpoints ==="
kubectl get endpoints -n "${NAMESPACE}"

echo
echo "=== Starting port-forwards ==="

kubectl port-forward svc/identity-service 18001:8000 -n "${NAMESPACE}" >/tmp/identity-pf.log 2>&1 &
IDENTITY_PF_PID=$!

kubectl port-forward svc/wallet-service 18002:8000 -n "${NAMESPACE}" >/tmp/wallet-pf.log 2>&1 &
WALLET_PF_PID=$!

kubectl port-forward svc/system-service 18003:8000 -n "${NAMESPACE}" >/tmp/system-pf.log 2>&1 &
SYSTEM_PF_PID=$!

kubectl port-forward svc/customer-portal 18004:8000 -n "${NAMESPACE}" >/tmp/customer-pf.log 2>&1 &
CUSTOMER_PF_PID=$!

kubectl port-forward svc/admin-portal 18005:8000 -n "${NAMESPACE}" >/tmp/admin-pf.log 2>&1 &
ADMIN_PF_PID=$!

kubectl port-forward svc/ops-portal 18006:8000 -n "${NAMESPACE}" >/tmp/ops-pf.log 2>&1 &
OPS_PF_PID=$!

cleanup() {
  echo
  echo "=== Cleaning up port-forwards ==="
  kill "${IDENTITY_PF_PID}" 2>/dev/null || true
  kill "${WALLET_PF_PID}" 2>/dev/null || true
  kill "${SYSTEM_PF_PID}" 2>/dev/null || true
  kill "${CUSTOMER_PF_PID}" 2>/dev/null || true
  kill "${ADMIN_PF_PID}" 2>/dev/null || true
  kill "${OPS_PF_PID}" 2>/dev/null || true
}

trap cleanup EXIT

sleep 5

echo
echo "=== Verifying identity-service ==="
curl -fsS http://127.0.0.1:18001/health
echo
curl -fsS http://127.0.0.1:18001/ready
echo
curl -fsS http://127.0.0.1:18001/version
echo

echo
echo "=== Verifying wallet-service ==="
curl -fsS http://127.0.0.1:18002/health
echo
curl -fsS http://127.0.0.1:18002/ready
echo
curl -fsS http://127.0.0.1:18002/version
echo

echo
echo "=== Verifying system-service ==="
curl -fsS http://127.0.0.1:18003/health
echo
curl -fsS http://127.0.0.1:18003/ready
echo
curl -fsS http://127.0.0.1:18003/version
echo
curl -fsS http://127.0.0.1:18003/status
echo

echo
echo "=== Verifying customer-portal ==="
curl -fsS http://127.0.0.1:18004/health
echo
curl -fsS http://127.0.0.1:18004/ready
echo
curl -fsS http://127.0.0.1:18004/version
echo
curl -fsS "http://127.0.0.1:18004/api/wallet/balances?username=customer1"
echo

echo
echo "=== Verifying admin-portal ==="
curl -fsS http://127.0.0.1:18005/health
echo
curl -fsS http://127.0.0.1:18005/ready
echo
curl -fsS http://127.0.0.1:18005/version
echo
curl -fsS http://127.0.0.1:18005/api/admin/system-summary
echo

echo
echo "=== Verifying ops-portal ==="
curl -fsS http://127.0.0.1:18006/health
echo
curl -fsS http://127.0.0.1:18006/ready
echo
curl -fsS http://127.0.0.1:18006/version
echo
curl -fsS http://127.0.0.1:18006/ops/dependencies
echo

echo
echo "verify-k8s.sh: PASS"