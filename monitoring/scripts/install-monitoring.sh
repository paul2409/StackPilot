#!/usr/bin/env bash
set -euo pipefail

APP_NS="${APP_NS:-stackpilot-dev}"
WALLET_DB_NAME="${WALLET_DB_NAME:-wallet_db}"
WALLET_DB_USER="${WALLET_DB_USER:-wallet_user}"
WALLET_DB_PASS="${WALLET_DB_PASS:-wallet_pass}"
IDENTITY_DB_NAME="${IDENTITY_DB_NAME:-identity_db}"
IDENTITY_DB_USER="${IDENTITY_DB_USER:-identity_user}"
IDENTITY_DB_PASS="${IDENTITY_DB_PASS:-identity_pass}"

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f monitoring/helm/kube-prometheus-stack-values.yaml

sed \
  -e "s/__APP_NS__/${APP_NS}/g" \
  -e "s/__WALLET_DB_NAME__/${WALLET_DB_NAME}/g" \
  -e "s/__WALLET_DB_USER__/${WALLET_DB_USER}/g" \
  -e "s/__WALLET_DB_PASS__/${WALLET_DB_PASS}/g" \
  monitoring/exporters/postgres-wallet-exporter.tmpl.yaml | kubectl apply -f -

sed \
  -e "s/__APP_NS__/${APP_NS}/g" \
  -e "s/__IDENTITY_DB_NAME__/${IDENTITY_DB_NAME}/g" \
  -e "s/__IDENTITY_DB_USER__/${IDENTITY_DB_USER}/g" \
  -e "s/__IDENTITY_DB_PASS__/${IDENTITY_DB_PASS}/g" \
  monitoring/exporters/postgres-identity-exporter.tmpl.yaml | kubectl apply -f -

kubectl apply -f monitoring/servicemonitors/
