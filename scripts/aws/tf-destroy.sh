#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------
# PURPOSE
# Runs terraform destroy for AWS infra.
# Uses run.tfvars if present so it matches how infra was created.
# ----------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${ROOT_DIR}/infra/aws/tf"
AWS_ENV="${ROOT_DIR}/infra/aws/aws.env"

LOG_DIR="${ROOT_DIR}/artifacts/logs/aws"
mkdir -p "${LOG_DIR}"

# ----------------------------------------------------------
# Load AWS environment
# ----------------------------------------------------------
source "${AWS_ENV}"

# ----------------------------------------------------------
# Optional per-run var-file
# ----------------------------------------------------------
RUN_TFVARS="${ROOT_DIR}/artifacts/aws/run.tfvars"
VAR_ARGS=()

if [[ -f "${RUN_TFVARS}" ]]; then
  echo "INFO: using run-specific var-file: ${RUN_TFVARS}"
  VAR_ARGS+=("-var-file=${RUN_TFVARS}")
fi

echo "== AWS: terraform destroy =="

terraform -chdir="${TF_DIR}" init -upgrade >/dev/null

terraform -chdir="${TF_DIR}" destroy \
  -auto-approve \
  -no-color \
  "${VAR_ARGS[@]}" \
  | tee "${LOG_DIR}/aws-destroy.log"

echo "PASS: terraform destroy"
