#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLAN="$ROOT/ci/logs/aws/plan.txt"

if [ ! -f "$PLAN" ]; then
  echo "FAIL: plan.txt not found. Run tf-plan first."
  exit 1
fi

echo "== PLAN GUARD =="

if grep -Eqi "aws_nat_gateway|aws_eip|aws_lb|aws_alb|aws_db_instance|aws_eks|aws_vpc|aws_subnet" "$PLAN"; then
  echo "FAIL: forbidden resource detected"
  grep -Ein "aws_nat_gateway|aws_eip|aws_lb|aws_alb|aws_db_instance|aws_eks|aws_vpc|aws_subnet" "$PLAN"
  exit 1
fi

echo "PASS: plan guard clean"
