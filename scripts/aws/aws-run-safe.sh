#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

AWS_ENV="$ROOT_DIR/infra/aws/aws.env"
TARGET_ENV="$ROOT_DIR/artifacts/aws/target.env"

RUN_DIR="$ROOT_DIR/artifacts/aws/run"
mkdir -p "$RUN_DIR"

ts() { date +"%Y-%m-%d_%H-%M-%S"; }

log() { echo "[$(date -u +"%Y-%m-%dT%H:%M:%SZ")] $*"; }

# ---- load env (no manual exports needed) ----
if [[ -f "$AWS_ENV" ]]; then
  # shellcheck disable=SC1090
  set -a; source "$AWS_ENV"; set +a
else
  echo "FAIL: missing $AWS_ENV"
  exit 1
fi

# ---- always destroy on exit ----
cleanup() {
  log "cleanup: terraform destroy (always)"
  if [[ -x "$ROOT_DIR/scripts/aws/tf-destroy.sh" ]]; then
    "$ROOT_DIR/scripts/aws/tf-destroy.sh" | tee "$RUN_DIR/$(ts)_destroy.log" || true
  else
    log "WARN: missing scripts/aws/tf-destroy.sh"
  fi

  if [[ -x "$ROOT_DIR/scripts/aws/cleanup-check.sh" ]]; then
    log "cleanup: cleanup-check"
    "$ROOT_DIR/scripts/aws/cleanup-check.sh" | tee "$RUN_DIR/$(ts)_cleanup-check.log" || true
  fi

  log "cleanup: done"
}
trap cleanup EXIT

log "aws-run: sts check"
"$ROOT_DIR/scripts/aws/sts-checks.sh" | tee "$RUN_DIR/$(ts)_sts.log"

log "aws-run: update operator IP"
"$ROOT_DIR/scripts/ops/update-ip.sh" | tee "$RUN_DIR/$(ts)_ip.log"

log "aws-run: terraform apply"
"$ROOT_DIR/scripts/aws/tf-apply.sh" | tee "$RUN_DIR/$(ts)_apply.log"

log "aws-run: write target.env"
"$ROOT_DIR/scripts/aws/target-env.sh" | tee "$RUN_DIR/$(ts)_targetenv.log"

if [[ ! -f "$TARGET_ENV" ]]; then
  echo "FAIL: target.env not created at $TARGET_ENV"
  exit 1
fi

log "aws-run: deploy"
"$ROOT_DIR/scripts/aws/deploy-aws.sh" | tee "$RUN_DIR/$(ts)_deploy.log"

log "aws-run: verify"
"$ROOT_DIR/scripts/aws/verify-aws.sh" | tee "$RUN_DIR/$(ts)_verify.log"

log "aws-run: PASS (destroy will still run via trap)"