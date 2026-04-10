#!/usr/bin/env bash
set -euo pipefail

echo "Checking Alertmanager pods"
kubectl -n monitoring get pods | grep alertmanager

echo
echo "Checking AlertmanagerConfig"
kubectl -n monitoring get alertmanagerconfig stackpilot-routing

echo
echo "Checking Discord webhook secret"
kubectl -n monitoring get secret stackpilot-discord-webhook

echo
echo "Checking PrometheusRule"
kubectl -n monitoring get prometheusrule stackpilot-phase4-routing

echo
echo "Checking firing alerts from Prometheus"
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 19090:9090 >/tmp/stackpilot-prom-phase4.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT
sleep 5
curl -fsG "http://127.0.0.1:19090/api/v1/alerts" | grep -E 'StackPilotAlertRoutingTest|WalletServiceNotReady|SystemServiceNotReady|PortalNotReady|StackPilotHighErrorRate|StackPilotRestartLoop|PostgresWalletDownSymptom' || true
