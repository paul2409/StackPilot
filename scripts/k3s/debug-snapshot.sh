#!/usr/bin/env bash
set -euo pipefail

echo "=== NODES ==="
kubectl get nodes -o wide || true
echo

echo "=== SYSTEM PODS ==="
kubectl -n kube-system get pods -o wide || true
echo

echo "=== DNS SERVICE ==="
kubectl -n kube-system get svc kube-dns -o wide || true
echo

echo "=== DNS ENDPOINTS ==="
kubectl -n kube-system get endpoints kube-dns -o wide || true
echo

echo "=== FLANNEL ANNOTATIONS ==="
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.flannel\.alpha\.coreos\.com/public-ip}{"\t"}{.metadata.annotations.flannel\.alpha\.coreos\.com/backend-type}{"\n"}{end}' || true
echo
