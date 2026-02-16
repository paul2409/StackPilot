#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_ART_DIR="${ROOT_DIR}/artifacts/aws"

PUBKEY_FILE="${AWS_ART_DIR}/stackpilot_ci_key.pub"
OUT="${AWS_ART_DIR}/run.tfvars"

[[ -f "${PUBKEY_FILE}" ]] || { echo "ERROR: pubkey not found: ${PUBKEY_FILE}"; exit 1; }

KEY_NAME="stackpilot-ephemeral-$(date -u +%Y%m%dT%H%M%SZ)"

# Public key must be a single OpenSSH line. Strip Windows CR (\r).
PUBKEY_CONTENT="$(tr -d '\r' < "${PUBKEY_FILE}")"

cat > "${OUT}" <<EOF
ssh_key_name   = "${KEY_NAME}"
ssh_public_key = "${PUBKEY_CONTENT}"
EOF

echo "PASS: wrote ${OUT}"