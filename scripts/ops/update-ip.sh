#!/usr/bin/env bash
set -euo pipefail

TF_DIR="infra/aws/tf"
OUT="$TF_DIR/operator.auto.tfvars"

echo "[aws-ip] detecting public ip..."

IP="$(curl -s https://checkip.amazonaws.com || true)"
if [ -z "${IP}" ]; then
  IP="$(curl -s https://ifconfig.me || true)"
fi

if [ -z "${IP}" ]; then
  echo "[aws-ip] FAIL: could not detect public IP"
  exit 1
fi

CIDR="${IP}/32"

cat > "${OUT}" <<EOF
my_ip_cidr = "${CIDR}"
EOF

echo "[aws-ip] OK: ${CIDR}"
echo "[aws-ip] wrote: ${OUT}"