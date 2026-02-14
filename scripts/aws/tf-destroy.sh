#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_ENV="$ROOT/infra/aws/aws.env"
TF_DIR="$ROOT/infra/aws/tf"
LOG_DIR="$ROOT/ci/logs/aws"

mkdir -p "$LOG_DIR"
source "$AWS_ENV"

terraform -chdir="$TF_DIR" destroy -auto-approve | tee "$LOG_DIR/destroy.txt"

echo "PASS: terraform destroy"
