#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MON_NS:-monitoring}"
PROM_SVC="${PROM_SVC:-kube-prometheus-stack-prometheus}"

kubectl -n "${MON_NS}" port-forward svc/"${PROM_SVC}" 19090:9090 >/tmp/stackpilot-prom-3d-pf.log 2>&1 &
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

query "Request Rate by Service" 'sum by (service) (rate(http_requests_total{environment="dev"}[5m]))'
query "Request Rate by Handler" 'sum by (handler) (rate(http_requests_total{environment="dev"}[5m]))'
query "Error Rate by Service" 'sum by (service) (rate(http_requests_total{environment="dev",status=~"4..|5.."}[5m]))'
query "Latency p95 by Service" 'histogram_quantile(0.95, sum by (le, service) (rate(http_request_duration_seconds_bucket{environment="dev"}[5m])))'
query "Latency p95 by Handler" 'histogram_quantile(0.95, sum by (le, handler) (rate(http_request_duration_seconds_bucket{environment="dev"}[5m])))'
query "Response Code Distribution" 'sum by (service, status) (rate(http_requests_total{environment="dev"}[5m]))'
query "Request Volume Table" 'sum by (service, handler) (rate(http_requests_total{environment="dev"}[5m]))'

echo
echo "3D query check complete."
