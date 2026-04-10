#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MON_NS:-monitoring}"
PROM_SVC="${PROM_SVC:-kube-prometheus-stack-prometheus}"

kubectl -n "${MON_NS}" port-forward svc/"${PROM_SVC}" 19090:9090 >/tmp/stackpilot-prom-3b-pf.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT
sleep 5

query() {
  local title="$1"
  local expr="$2"
  echo
  echo "==== ${title} ===="
  curl -fsG "http://127.0.0.1:19090/api/v1/query" \
    --data-urlencode "query=${expr}"
  echo
}

NS='stackpilot-dev'
DEPLOY_RE='identity-service|wallet-service|system-service|customer-portal|admin-portal|ops-portal|postgres-identity|postgres-wallet'
POD_RE='identity-service.*|wallet-service.*|system-service.*|customer-portal.*|admin-portal.*|ops-portal.*|postgres-identity.*|postgres-wallet.*'

query "Desired Replicas" "kube_deployment_spec_replicas{namespace=\"${NS}\",deployment=~\"${DEPLOY_RE}\"}"
query "Available Replicas" "kube_deployment_status_replicas_available{namespace=\"${NS}\",deployment=~\"${DEPLOY_RE}\"}"
query "Unavailable Replicas" "kube_deployment_status_replicas_unavailable{namespace=\"${NS}\",deployment=~\"${DEPLOY_RE}\"}"
query "Restart Increase 15m" "sum by (pod) (increase(kube_pod_container_status_restarts_total{namespace=\"${NS}\",pod=~\"${POD_RE}\"}[15m]))"
query "Pod Phase Distribution" "sum by (phase) (kube_pod_status_phase{namespace=\"${NS}\",pod=~\"${POD_RE}\",phase=~\"Pending|Running|Succeeded|Failed|Unknown\"})"
query "Waiting Reasons" "sum by (reason) (kube_pod_container_status_waiting_reason{namespace=\"${NS}\",pod=~\"${POD_RE}\"})"
query "Pods Not Ready" "max by (pod) ((1 - kube_pod_status_ready{condition=\"true\",namespace=\"${NS}\",pod=~\"${POD_RE}\"}) > 0)"
query "Pending Pods" "sum by (pod) (kube_pod_status_phase{namespace=\"${NS}\",pod=~\"${POD_RE}\",phase=\"Pending\"})"
query "Restart Spike Snapshot 5m" "sum by (pod) (increase(kube_pod_container_status_restarts_total{namespace=\"${NS}\",pod=~\"${POD_RE}\"}[5m]))"

echo
echo "3B query check complete."
