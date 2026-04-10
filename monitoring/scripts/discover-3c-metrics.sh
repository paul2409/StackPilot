#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MON_NS:-monitoring}"
PROM_SVC="${PROM_SVC:-kube-prometheus-stack-prometheus}"

kubectl -n "${MON_NS}" port-forward svc/"${PROM_SVC}" 19090:9090 >/tmp/stackpilot-prom-3c-discover-pf.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT
sleep 5

echo "==== Metric name discovery for 3C ===="
for match in \
  wallet_dependency_state \
  dependency_check_failures_total \
  wallet_db_check_failures_total \
  identity_db_check_failures_total \
  system_dependency_unready_total \
  ops_dependency_unready_total \
  customer_portal_upstream_failures_total \
  admin_portal_upstream_failures_total \
  service_ready_state
do
  echo
  echo "-- ${match} --"
  curl -fsG "http://127.0.0.1:19090/api/v1/label/__name__/values" | tr ',' '\n' | grep "${match}" || true
done
