#!/usr/bin/env bash
set -Eeuo pipefail

log() { printf "\n[%s] %s\n" "$(date +'%Y-%m-%d %H:%M:%S')" "$*"; }

LOG_DIR="artifacts/logs/aws"

main_rc=0
failed_target=""
cleanup_ran=0

ensure_dirs_and_clear_logs() {
  mkdir -p "${LOG_DIR}"

  : > "${LOG_DIR}/deploy-aws.log"
  : > "${LOG_DIR}/verify-aws.log"
  : > "${LOG_DIR}/cleanup_aws-destroy.log"
  : > "${LOG_DIR}/cleanup_aws-clean-check.log"
}

cleanup() {
  if [[ "${cleanup_ran}" -eq 1 ]]; then
    exit "${main_rc}"
  fi
  cleanup_ran=1

  log "CLEANUP: aws-destroy (always)"
  make aws-destroy 2>&1 | tee "${LOG_DIR}/cleanup_aws-destroy.log" || true

  log "CLEANUP: aws-clean-check (always)"
  make aws-clean-check 2>&1 | tee "${LOG_DIR}/cleanup_aws-clean-check.log" || true

  if [[ "${main_rc}" -eq 0 ]]; then
    log "PASS: aws-cycle-debug"
  else
    log "FAIL: aws-cycle-debug (failed_target=${failed_target:-unknown}, rc=${main_rc})"
  fi

  log "Logs saved in: ${LOG_DIR}"
  exit "${main_rc}"
}

trap cleanup EXIT INT TERM

run_make() {
  local target="$1"
  local logfile="${LOG_DIR}/${target}.log"

  log "STEP: ${target}"
  log "LOG:  ${logfile}"

  set +e
  make --no-print-directory "${target}" 2>&1 | tee "${logfile}"
  local rc="${PIPESTATUS[0]}"
  set -e

  if [[ "${rc}" -ne 0 ]]; then
    main_rc="${rc}"
    failed_target="${target}"
    log "ERROR: target failed -> ${target} (rc=${rc})"
    return "${rc}"
  fi

  return 0
}

ensure_dirs_and_clear_logs
log "AWS: deterministic lifecycle starting"

run_make deploy-aws
run_make verify-aws

main_rc=0
exit 0
