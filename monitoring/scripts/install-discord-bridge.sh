#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${ENV_FILE:-env/discord-alerts.env}"

if [ ! -f "${ENV_FILE}" ]; then
  echo "Missing ${ENV_FILE}"
  echo "Copy env/discord-alerts.env.example to ${ENV_FILE} and set DISCORD_WEBHOOK_URL."
  exit 1
fi

# shellcheck disable=SC1090
. "${ENV_FILE}"

if [ -z "${DISCORD_WEBHOOK_URL:-}" ]; then
  echo "DISCORD_WEBHOOK_URL is empty in ${ENV_FILE}"
  exit 1
fi

kubectl -n monitoring create secret generic stackpilot-discord-webhook \
  --from-literal=url="${DISCORD_WEBHOOK_URL}" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f monitoring/bridge/alertmanager-discord-bridge.yaml
kubectl apply -f monitoring/alertmanager/stackpilot-alertmanager-config.yaml
kubectl apply -f monitoring/alerts/m9-phase4-routing-test-rules.yaml

kubectl -n monitoring rollout status deploy/alertmanager-discord-bridge --timeout=180s

echo
echo "Discord bridge installed."
echo "Wait about 1-2 minutes for StackPilotAlertRoutingTest to route."
