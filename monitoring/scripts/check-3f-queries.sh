#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MON_NS:-monitoring}"
PROM_SVC="${PROM_SVC:-kube-prometheus-stack-prometheus}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
NS_REGEX="${NS_REGEX:-stackpilot-dev|monitoring|argocd|ingress-nginx}"

kubectl -n "${MON_NS}" port-forward svc/"${PROM_SVC}" 19090:9090 >/tmp/stackpilot-prom-3f-pf.log 2>&1 &
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

query "Current Service Build Info" "max by (service, version, git_sha, build_time, environment) (service_build_info{environment=\"${ENVIRONMENT}\"})"
query "Version / Build Metadata Table" "max by (service, version, git_sha, build_time, environment) (service_build_info{environment=\"${ENVIRONMENT}\"})"
query "Readiness After Rollout" "max by (service) (service_ready_state{environment=\"${ENVIRONMENT}\"})"
query "Restart Count After Rollout" "sum by (pod) (increase(kube_pod_container_status_restarts_total{namespace=~\"${NS_REGEX}\"}[15m]))"
query "Request Behavior After Rollout" "sum by (job) (rate(http_requests_total[5m]))"
query "Error Behavior After Rollout" "sum by (job) (rate(http_requests_total{status=~\"4..|5..\"}[5m]))"
query "Current Readiness Snapshot" "max by (service) (service_ready_state{environment=\"${ENVIRONMENT}\"})"
query "Current Version Presence" "max by (service, version) (service_build_info{environment=\"${ENVIRONMENT}\"})"

echo
echo "3F query check complete."
