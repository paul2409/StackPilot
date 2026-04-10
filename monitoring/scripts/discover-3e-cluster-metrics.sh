#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MON_NS:-monitoring}"
PROM_SVC="${PROM_SVC:-kube-prometheus-stack-prometheus}"

kubectl -n "${MON_NS}" port-forward svc/"${PROM_SVC}" 19090:9090 >/tmp/stackpilot-prom-3e-discover.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT
sleep 5

echo "==== 3E CLUSTER HEALTH METRIC DISCOVERY ===="
for q in \
  kube_node_status_condition \
  node_cpu_seconds_total \
  node_memory_MemAvailable_bytes \
  node_memory_MemTotal_bytes \
  kube_pod_status_phase \
  kube_pod_container_status_restarts_total \
  kube_deployment_spec_replicas \
  kube_deployment_status_replicas_available \
  kube_deployment_status_replicas_unavailable \
  kube_pod_container_status_waiting_reason
do
  echo
  echo "-- ${q} --"
  curl -fsG "http://127.0.0.1:19090/api/v1/label/__name__/values" | tr ',' '\n' | grep "${q}" || true
done
echo
echo "Done."
