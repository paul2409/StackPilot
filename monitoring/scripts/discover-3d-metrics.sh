#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MON_NS:-monitoring}"
PROM_SVC="${PROM_SVC:-kube-prometheus-stack-prometheus}"

kubectl -n "${MON_NS}" port-forward svc/"${PROM_SVC}" 19090:9090 >/tmp/stackpilot-prom-3d-discover-pf.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT
sleep 5

echo "==== Metric name discovery for 3D ===="
for match in \
  http_requests_total \
  http_request_duration_seconds_bucket \
  http_request_duration_seconds_sum \
  http_request_duration_seconds_count \
  http_request_size_bytes \
  http_response_size_bytes
do
  echo
  echo "-- ${match} --"
  curl -fsG "http://127.0.0.1:19090/api/v1/label/__name__/values" | tr ',' '\n' | grep "${match}" || true
done
