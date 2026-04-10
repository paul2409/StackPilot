#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MON_NS:-monitoring}"
PROM_SVC="${PROM_SVC:-kube-prometheus-stack-prometheus}"

kubectl -n "${MON_NS}" port-forward svc/"${PROM_SVC}" 19090:9090 >/tmp/stackpilot-prom-3c-pf.log 2>&1 &
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

query "Wallet Dependency State" 'max(wallet_dependency_state{dependency="postgres-wallet"})'
query "Dependency Failure Rate" 'sum by (dependency) (rate(dependency_check_failures_total[5m]))'
query "Wallet DB Failure Rate" 'rate(wallet_db_check_failures_total[5m])'
query "Identity DB Failure Rate" 'rate(identity_db_check_failures_total[5m])'
query "System Dependency Unready" 'rate(system_dependency_unready_total[5m])'
query "Ops Dependency Unready" 'rate(ops_dependency_unready_total[5m])'
query "Customer Portal Upstream Failures" 'rate(customer_portal_upstream_failures_total[5m])'
query "Admin Portal Upstream Failures" 'rate(admin_portal_upstream_failures_total[5m])'
query "Current Readiness Impact Snapshot" 'max by (service) (service_ready_state{environment="dev"})'

echo
echo "3C query check complete."
