#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AWS_ENV="$ROOT/infra/aws/aws.env"
LOG_DIR="$ROOT/ci/logs/aws"

mkdir -p "$LOG_DIR"

if [ ! -f "$AWS_ENV" ]; then
  echo "FAIL: aws.env not found at $AWS_ENV"
  exit 1
fi

source "$AWS_ENV"

echo "== AWS STS CHECK ==" | tee "$LOG_DIR/sts.txt"
echo "PROFILE: $AWS_PROFILE" | tee -a "$LOG_DIR/sts.txt"
echo "REGION:  $AWS_REGION"  | tee -a "$LOG_DIR/sts.txt"

aws sts get-caller-identity | tee -a "$LOG_DIR/sts.txt"

echo "PASS: sts-check"
