#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { echo "== AWS STS CHECK == $*"; }
die() { echo "FAIL: $*" >&2; exit 1; }

# Load your aws.env if present (local convenience)
AWS_ENV="${ROOT_DIR}/infra/aws/aws.env"
if [[ -f "${AWS_ENV}" ]]; then
  # shellcheck disable=SC1090
  source "${AWS_ENV}"
fi

# ------------------------------------------------------------
# Auth mode detection
# ------------------------------------------------------------
# CI mode: GitHub Secrets exported into env (AWS_ACCESS_KEY_ID present)
# Local mode: use AWS_PROFILE from aws.env or your shell
USE_PROFILE=0
if [[ -n "${AWS_ACCESS_KEY_ID:-}" ]]; then
  log "auth mode: env creds (CI-style)"
  USE_PROFILE=0
else
  log "auth mode: profile (local-style)"
  USE_PROFILE=1
  [[ -n "${AWS_PROFILE:-}" ]] || die "AWS_PROFILE not set and no AWS_ACCESS_KEY_ID env creds found"
fi

# Region must exist one way or another
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
[[ -n "${REGION}" ]] || die "AWS_REGION (or AWS_DEFAULT_REGION) not set"

# ------------------------------------------------------------
# Build AWS CLI args
# ------------------------------------------------------------
AWS_ARGS=(--region "${REGION}")
if [[ "${USE_PROFILE}" -eq 1 ]]; then
  AWS_ARGS+=(--profile "${AWS_PROFILE}")
fi

# ------------------------------------------------------------
# Run identity check
# ------------------------------------------------------------
log "region: ${REGION}"
if [[ "${USE_PROFILE}" -eq 1 ]]; then
  log "profile: ${AWS_PROFILE}"
fi

aws sts get-caller-identity "${AWS_ARGS[@]}" >/dev/null \
  || die "aws sts get-caller-identity failed (check creds/region)"

# Optional: print identity (useful for logs)
aws sts get-caller-identity "${AWS_ARGS[@]}" --output json

log "PASS: sts identity ok"