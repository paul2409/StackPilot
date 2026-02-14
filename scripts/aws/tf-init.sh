#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_ENV="$ROOT/infra/aws/aws.env"
TF_DIR="$ROOT/infra/aws/tf"
LOG_DIR="$ROOT/ci/logs/aws"

mkdir -p "$LOG_DIR"
source "$AWS_ENV"

terraform -chdir="$TF_DIR" init -upgrade | tee "$LOG_DIR/init.txt"

echo "PASS: terraform init"
