#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MON_NS:-monitoring}"
APP_NS="${APP_NS:-stackpilot-dev}"
PROM_SVC="${PROM_SVC:-kube-prometheus-stack-prometheus}"
INGRESS_NS="${INGRESS_NS:-ingress-nginx}"
INGRESS_LABEL_SELECTOR="${INGRESS_LABEL_SELECTOR:-app.kubernetes.io/component=controller,app.kubernetes.io/instance=ingress-nginx,app.kubernetes.io/name=ingress-nginx}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "FAIL: missing command $1"
    exit 1
  }
}

need kubectl
need curl
need grep
need mktemp

check_deploy() {
  kubectl -n "${MON_NS}" rollout status deployment/"$1" --timeout=180s >/dev/null
  echo "PASS: deployment $1 ready"
}

check_servicemonitor() {
  kubectl -n "${MON_NS}" get servicemonitor "$1" >/dev/null
  echo "PASS: ServiceMonitor $1 exists"
}

port_forward_service_metrics() {
  local ns="$1"
  local svc="$2"
  local local_port="$3"
  local remote_port="$4"
  local metric="$5"

  kubectl -n "${ns}" port-forward svc/"${svc}" "${local_port}:${remote_port}" >/tmp/"${svc}"-pf.log 2>&1 &
  local pf_pid=$!
  trap 'kill ${pf_pid} >/dev/null 2>&1 || true' RETURN
  sleep 3

  curl -fsS "http://127.0.0.1:${local_port}/metrics" | grep -q "${metric}"
  echo "PASS: ${svc} exposes ${metric}"

  kill "${pf_pid}" >/dev/null 2>&1 || true
  trap - RETURN
}

check_exporter() {
  local svc="$1"
  local local_port="$2"

  kubectl -n "${MON_NS}" port-forward svc/"${svc}" "${local_port}:9187" >/tmp/"${svc}"-pf.log 2>&1 &
  local pf_pid=$!
  trap 'kill ${pf_pid} >/dev/null 2>&1 || true' RETURN
  sleep 3

  curl -fsS "http://127.0.0.1:${local_port}/metrics" | grep -Eq 'pg_up|postgres_exporter'
  echo "PASS: ${svc} exporter metrics present"

  kill "${pf_pid}" >/dev/null 2>&1 || true
  trap - RETURN
}

check_ingress_metrics() {
  local local_port="${1:-19254}"

  local pod
  pod="$(kubectl -n "${INGRESS_NS}" get pods -l "${INGRESS_LABEL_SELECTOR}" -o jsonpath='{.items[0].metadata.name}')"

  if [ -z "${pod}" ]; then
    echo "FAIL: could not find ingress controller pod in namespace ${INGRESS_NS}"
    exit 1
  fi

  kubectl -n "${INGRESS_NS}" port-forward pod/"${pod}" "${local_port}:10254" >/tmp/ingress-controller-pf.log 2>&1 &
  local pf_pid=$!
  trap 'kill ${pf_pid} >/dev/null 2>&1 || true' RETURN
  sleep 3

  curl -fsS "http://127.0.0.1:${local_port}/metrics" | grep -Eq 'nginx_ingress_controller_requests|nginx_ingress_controller_nginx_process_connections'
  echo "PASS: ingress controller metrics present via pod/${pod}"

  kill "${pf_pid}" >/dev/null 2>&1 || true
  trap - RETURN
}

check_prometheus_targets() {
  kubectl -n "${MON_NS}" get svc "${PROM_SVC}" >/dev/null

  kubectl -n "${MON_NS}" port-forward svc/"${PROM_SVC}" 19090:9090 >/tmp/prometheus-pf.log 2>&1 &
  local pf_pid=$!
  trap 'kill ${pf_pid} >/dev/null 2>&1 || true' RETURN
  sleep 5

  local targets
  targets="$(curl -fsS "http://127.0.0.1:19090/api/v1/targets")"

  echo "${targets}" | grep -q '"health":"up"'
  echo "PASS: Prometheus has at least one healthy scrape target"

  kill "${pf_pid}" >/dev/null 2>&1 || true
  trap - RETURN
}

echo "== Monitoring stack =="
check_deploy kube-prometheus-stack-operator
check_deploy kube-prometheus-stack-kube-state-metrics
check_deploy kube-prometheus-stack-grafana
check_deploy postgres-wallet-exporter
check_deploy postgres-identity-exporter

echo
echo "== ServiceMonitors =="
for sm in \
  identity-service \
  wallet-service \
  system-service \
  customer-portal \
  admin-portal \
  ops-portal \
  postgres-wallet-exporter \
  postgres-identity-exporter \
  ingress-nginx-controller
do
  check_servicemonitor "${sm}"
done

echo
echo "== App metrics endpoints =="
port_forward_service_metrics "${APP_NS}" identity-service 19001 8000 identity_db_check_failures_total
port_forward_service_metrics "${APP_NS}" wallet-service 19002 8000 wallet_db_check_failures_total
port_forward_service_metrics "${APP_NS}" system-service 19003 8000 system_summary_requests_total
port_forward_service_metrics "${APP_NS}" customer-portal 19004 8000 customer_portal_wallet_requests_total
port_forward_service_metrics "${APP_NS}" admin-portal 19005 8000 admin_portal_summary_requests_total
port_forward_service_metrics "${APP_NS}" ops-portal 19006 8000 ops_dependency_diagnostics_requests_total

echo
echo "== Postgres exporter metrics =="
check_exporter postgres-wallet-exporter 19187
check_exporter postgres-identity-exporter 19188

echo
echo "== Ingress controller metrics =="
check_ingress_metrics 19254

echo
echo "== Prometheus targets =="
check_prometheus_targets

echo
echo "PASS: Phase 2 metrics verification complete"