#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load AWS env (profile/region/ssh info)
set -a
source "$ROOT_DIR/infra/aws/aws.env"
set +a

AWS_TF_DIR="${AWS_TF_DIR:-$ROOT_DIR/infra/aws/tf}"
OUT_DIR="$ROOT_DIR/artifacts/aws"
OUT_FILE="$OUT_DIR/target.env"

mkdir -p "$OUT_DIR"

# Pull from terraform outputs (ONE time, here)
PUBLIC_IP="$(terraform -chdir="$AWS_TF_DIR" output -raw public_ip 2>/dev/null || true)"
PUBLIC_DNS="$(terraform -chdir="$AWS_TF_DIR" output -raw public_dns 2>/dev/null || true)"
API_PORT="$(terraform -chdir="$AWS_TF_DIR" output -raw api_port 2>/dev/null || true)"

if [[ -z "${API_PORT}" ]]; then
  echo "FAIL: terraform output api_port is empty" >&2
  exit 1
fi

# Prefer IP if present, else DNS
TARGET_HOST="${PUBLIC_IP:-$PUBLIC_DNS}"
if [[ -z "${TARGET_HOST}" ]]; then
  echo "FAIL: terraform outputs public_ip/public_dns are empty" >&2
  exit 1
fi

cat > "$OUT_FILE" <<EOF
TARGET_HOST=$TARGET_HOST
SSH_HOST=$TARGET_HOST
API_PORT=$API_PORT
BASE_URL=http://$TARGET_HOST:$API_PORT
EOF

echo "PASS: wrote $OUT_FILE"
cat "$OUT_FILE"