#!/usr/bin/env bash
set -euo pipefail

echo "== phase 5 PrometheusRule =="
kubectl -n monitoring get prometheusrule stackpilot-phase5-real-alerts -o yaml | sed -n '1,260p'
echo

echo "== alert names =="
kubectl -n monitoring get prometheusrule stackpilot-phase5-real-alerts -o yaml | grep 'alert:' || true
echo

echo "== runbook references =="
kubectl -n monitoring get prometheusrule stackpilot-phase5-real-alerts -o yaml | grep 'runbook:' || true
echo

echo "== current matching alerts from Prometheus =="
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 19090:9090 >/tmp/stackpilot-prom-phase5.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT
sleep 5
curl -fsG "http://127.0.0.1:19090/api/v1/alerts" | grep -E 'WalletServiceNotReady|SystemServiceNotReady|CustomerPortalNotReady|AdminPortalNotReady|OpsPortalNotReady|PostgresWalletDownSymptom|PostgresIdentityDownSymptom|WalletDependencyPropagation|StackPilotRestartLoop|StackPilotDeploymentUnavailable|StackPilotHighErrorRate|StackPilotHighLatencyP95' || true
