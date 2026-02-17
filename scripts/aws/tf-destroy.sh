#!/usr/bin/env bash
set -euo pipefail

# ----------------------------------------------------------
# PURPOSE
# Runs terraform destroy for AWS infra.
# Uses run.tfvars if present so it matches how infra was created.
#
# CI RULE:
# - If AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY exist, DO NOT use profiles.
# - Do not source aws.env in CI mode (it exports AWS_PROFILE).
# ----------------------------------------------------------

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${ROOT_DIR}/infra/aws/tf"
AWS_ENV="${ROOT_DIR}/infra/aws/aws.env"

LOG_DIR="${ROOT_DIR}/artifacts/logs/aws"
mkdir -p "${LOG_DIR}"

log() { echo "[tf-destroy] $*"; }

# ----------------------------------------------------------
# Auth mode detection
# ----------------------------------------------------------
CI_ENV_CREDS=0
if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  CI_ENV_CREDS=1
fi

# Local convenience only
if [[ "${CI_ENV_CREDS}" -eq 0 && -f "${AWS_ENV}" ]]; then
  # shellcheck disable=SC1090
  source "${AWS_ENV}"
else
  # Hard guard: prevent accidental profile-mode in CI
  unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_SDK_LOAD_CONFIG || true
fi

# ----------------------------------------------------------
# Optional per-run var-file
# ----------------------------------------------------------
RUN_TFVARS="${ROOT_DIR}/artifacts/aws/run.tfvars"
VAR_ARGS=()

if [[ -f "${RUN_TFVARS}" ]]; then
  log "INFO: using run-specific var-file: ${RUN_TFVARS}"
  VAR_ARGS+=("-var-file=${RUN_TFVARS}")
fi

log "== AWS: terraform destroy =="

terraform -chdir="${TF_DIR}" init -upgrade >/dev/null

terraform -chdir="${TF_DIR}" destroy \
  -auto-approve \
  -no-color \
  "${VAR_ARGS[@]}" \
  | tee "${LOG_DIR}/aws-destroy.log"

log "PASS: terraform destroy"
