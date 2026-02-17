#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

log() { echo "== AWS STS CHECK == $*"; }
die() { echo "FAIL: $*" >&2; exit 1; }

# Load aws.env for LOCAL convenience only.
# IMPORTANT: aws.env often sets AWS_PROFILE, which MUST NOT affect CI env-creds mode.
AWS_ENV="${ROOT_DIR}/infra/aws/aws.env"
if [[ -f "${AWS_ENV}" ]]; then
  # shellcheck disable=SC1090
  source "${AWS_ENV}"
fi

# ------------------------------------------------------------
# Auth mode detection
# ------------------------------------------------------------
# If CI env creds exist, we MUST NOT use AWS_PROFILE at all.
USE_PROFILE=0
if [[ -n "${AWS_ACCESS_KEY_ID:-}" && -n "${AWS_SECRET_ACCESS_KEY:-}" ]]; then
  log "auth mode: env creds (CI-style)"

  # Hard override: prevent AWS CLI from trying any profile lookup
  unset AWS_PROFILE || true
  unset AWS_DEFAULT_PROFILE || true
  USE_PROFILE=0
else
  log "auth mode: profile (local-style)"
  USE_PROFILE=1

  # Allow either aws.env or shell to provide it
  [[ -n "${AWS_PROFILE:-}" ]] || die "AWS_PROFILE not set and no AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY env creds found"
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

aws sts get-caller-identity "${AWS_ARGS[@]}" --output json
log "PASS: sts identity ok"
