#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MON_NS:-monitoring}"
PROM_SVC="${PROM_SVC:-kube-prometheus-stack-prometheus}"

kubectl -n "${MON_NS}" port-forward svc/"${PROM_SVC}" 19090:9090 >/tmp/stackpilot-prom-3b-discover-pf.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT
sleep 5

echo "==== Metric name discovery for 3B ===="
for match in \
  kube_deployment_spec_replicas \
  kube_deployment_status_replicas_available \
  kube_deployment_status_replicas_unavailable \
  kube_pod_container_status_restarts_total \
  kube_pod_status_phase \
  kube_pod_container_status_waiting_reason \
  kube_pod_status_ready
do
  echo
  echo "-- ${match} --"
  curl -fsG "http://127.0.0.1:19090/api/v1/label/__name__/values" | tr ',' '\n' | grep "${match}" || true
done
