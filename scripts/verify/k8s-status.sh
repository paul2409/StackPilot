#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="${NAMESPACE:-stackpilot}"

echo "=== Kubernetes Context ==="
kubectl config current-context

echo
echo "=== Nodes ==="
kubectl get nodes -o wide

echo
echo "=== Pods ==="
kubectl get pods -n "${NAMESPACE}" -o wide

echo
echo "=== Deployments ==="
kubectl get deployments -n "${NAMESPACE}"

echo
echo "=== Services ==="
kubectl get svc -n "${NAMESPACE}"

echo
echo "=== Ingress ==="
kubectl get ingress -n "${NAMESPACE}"

echo
echo "=== Endpoints ==="
kubectl get endpoints -n "${NAMESPACE}"