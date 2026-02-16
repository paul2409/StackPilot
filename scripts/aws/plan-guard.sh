#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="$ROOT_DIR/infra/aws/tf"

PLAN_OUT="${ROOT_DIR}/artifacts/aws/tf.plan"
mkdir -p "${ROOT_DIR}/artifacts/aws"

echo "== PLAN GUARD =="
echo "writing plan: ${PLAN_OUT}"

terraform -chdir="${TF_DIR}" plan -no-color -out "${PLAN_OUT}" >/dev/null

# Only block MANAGED resources of these types (data sources are allowed)
FORBIDDEN_TYPES='["aws_vpc","aws_subnet","aws_alb","aws_db_instance","aws_eks"]'

if terraform -chdir="${TF_DIR}" show -json "${PLAN_OUT}" \
  | jq -e --argjson bad "${FORBIDDEN_TYPES}" '
      [.resource_changes[]
        | select(.mode=="managed")
        | select(.type as $t | $bad | index($t))
      ] | length > 0
    ' >/dev/null; then
  echo "FAIL: forbidden managed resource detected"
  terraform -chdir="${TF_DIR}" show -json "${PLAN_OUT}" \
    | jq -r --argjson bad "${FORBIDDEN_TYPES}" '
        .resource_changes[]
        | select(.mode=="managed")
        | select(.type as $t | $bad | index($t))
        | "- \(.type) \(.name) (\(.change.actions|join(",")))"
      '
  exit 1
fi

echo "PASS: plan guard (data sources allowed)"