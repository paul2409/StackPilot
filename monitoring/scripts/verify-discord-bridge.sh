#!/usr/bin/env bash
set -euo pipefail

echo "== bridge deployment =="
kubectl -n monitoring get deploy alertmanager-discord-bridge
echo

echo "== bridge pod =="
kubectl -n monitoring get pods -l app=alertmanager-discord-bridge -o wide
echo

echo "== bridge service =="
kubectl -n monitoring get svc alertmanager-discord-bridge
echo

echo "== bridge endpoints =="
kubectl -n monitoring get endpoints alertmanager-discord-bridge
echo

echo "== alertmanager config =="
kubectl -n monitoring get alertmanagerconfig stackpilot-routing -o yaml | sed -n '1,220p'
echo

echo "== bridge logs =="
kubectl -n monitoring logs deploy/alertmanager-discord-bridge --tail=200 || true
echo

echo "== alertmanager logs with notify lines =="
kubectl -n monitoring logs statefulset/alertmanager-kube-prometheus-stack-alertmanager --tail=200 | grep -iE 'notify|error|discord|webhook' || true
echo

echo "== firing alerts from prometheus =="
kubectl -n monitoring port-forward svc/kube-prometheus-stack-prometheus 19090:9090 >/tmp/stackpilot-prom-bridge.log 2>&1 &
PF_PID=$!
trap 'kill ${PF_PID} >/dev/null 2>&1 || true' EXIT
sleep 5
curl -fsG "http://127.0.0.1:19090/api/v1/alerts" | grep -E 'StackPilotAlertRoutingTest|WalletServiceNotReady|SystemServiceNotReady|PortalNotReady|StackPilotHighErrorRate|StackPilotRestartLoop|PostgresWalletDownSymptom' || true
