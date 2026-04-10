#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MON_NS:-monitoring}"
PROM_SVC="${PROM_SVC:-kube-prometheus-stack-prometheus}"
NS_REGEX="${NS_REGEX:-stackpilot-dev|monitoring|argocd|ingress-nginx}"

kubectl -n "${MON_NS}" port-forward svc/"${PROM_SVC}" 19090:9090 >/tmp/stackpilot-prom-3e-check.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT
sleep 5

query() {
  local title="$1"
  local expr="$2"
  echo
  echo "==== ${title} ===="
  curl -fsG "http://127.0.0.1:19090/api/v1/query" --data-urlencode "query=${expr}"
  echo
}

query "Node Readiness" 'max by (node) (kube_node_status_condition{condition="Ready",status="true"})'
query "Node CPU Usage" '100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])))'
query "Node Memory Usage" '100 * (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes))'
query "Pod Count by Phase" "sum by (phase) (kube_pod_status_phase{namespace=~\"${NS_REGEX}\"})"
query "Restart Increase" "sum by (pod) (increase(kube_pod_container_status_restarts_total{namespace=~\"${NS_REGEX}\"}[15m]))"
query "Deployment Replicas Desired" "kube_deployment_spec_replicas{namespace=~\"${NS_REGEX}\"}"
query "Deployment Replicas Available" "kube_deployment_status_replicas_available{namespace=~\"${NS_REGEX}\"}"
query "Unavailable Replicas" "kube_deployment_status_replicas_unavailable{namespace=~\"${NS_REGEX}\"}"
query "Container Waiting Reasons" "sum by (reason) (kube_pod_container_status_waiting_reason{namespace=~\"${NS_REGEX}\"})"

echo
echo "3E cluster query check complete."
