#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MON_NS:-monitoring}"
PROM_SVC="${PROM_SVC:-kube-prometheus-stack-prometheus}"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required"
  exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required"
  exit 1
fi

kubectl -n "${MON_NS}" port-forward svc/"${PROM_SVC}" 19090:9090 >/tmp/stackpilot-prom-pf.log 2>&1 &
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

query "Current Service Readiness" 'max by (service) (service_ready_state{environment="dev"})'
query "Service Readiness Over Time Instant Sample" 'service_ready_state{environment="dev"}'
query "Wallet Dependency State" 'max(wallet_dependency_state{dependency="postgres-wallet"})'
query "Dependency Failure Rate (5m)" 'sum by (dependency) (rate(dependency_check_failures_total[5m]))'
query "Readiness Changes (15m)" 'changes(service_ready_state{environment="dev"}[15m])'
query "Readiness Snapshot" 'max by (service, environment) (service_ready_state{environment="dev"})'
query "Propagation Signals" 'rate(wallet_db_check_failures_total[5m]) or rate(identity_db_check_failures_total[5m]) or rate(system_dependency_unready_total[5m]) or rate(ops_dependency_unready_total[5m]) or rate(customer_portal_upstream_failures_total[5m]) or rate(admin_portal_upstream_failures_total[5m])'

echo
echo "3A query check complete."
