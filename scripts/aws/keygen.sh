#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_ART_DIR="${ROOT_DIR}/artifacts/aws"

KEY_PATH="${AWS_ART_DIR}/stackpilot_ci_key"

mkdir -p "${AWS_ART_DIR}"

# fresh key every run
rm -f "${KEY_PATH}" "${KEY_PATH}.pub"

ssh-keygen -t ed25519 -N "" -f "${KEY_PATH}" >/dev/null
chmod 600 "${KEY_PATH}"

echo "PASS: generated keypair"
echo "private: ${KEY_PATH}"
echo "public:  ${KEY_PATH}.pub"
