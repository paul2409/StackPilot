#!/usr/bin/env bash
set -euo pipefail

# scripts/k3s/install-server.sh
# Host-side: boots control VM, runs server setup inside it, then collects logs.
# Key fix: server setup uses timeouts so it won't hang forever.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VAGRANT_DIR="${ROOT_DIR}/vagrant"

CONTROL_NAME="${CONTROL_NAME:-control}"
NODE_IP="${NODE_IP:-192.168.56.10}"

# Pin one version everywhere (binary must match this expectation)
K3S_VERSION="${K3S_VERSION:-v1.34.4+k3s1}"

LOG_DIR="${ROOT_DIR}/artifacts/logs/k3s"
mkdir -p "${LOG_DIR}"
TS="$(date +%Y%m%d-%H%M%S)"

INSTALL_LOG="${LOG_DIR}/install-server-${TS}.log"
STATUS_LOG="${LOG_DIR}/status-server-${TS}.log"
JOURNAL_LOG="${LOG_DIR}/journal-server-${TS}.log"
DEBUG_LOG="${LOG_DIR}/debug-server-${TS}.log"

log() { echo "$*" | tee -a "${INSTALL_LOG}"; }
: > "${INSTALL_LOG}"

log "[host] control=${CONTROL_NAME} node_ip=${NODE_IP} k3s_version=${K3S_VERSION}"
log "[host] vagrant_dir=${VAGRANT_DIR}"
log ""

cd "${VAGRANT_DIR}"

log "[host] ensuring VM is up..."
vagrant up "${CONTROL_NAME}" 2>&1 | tee -a "${INSTALL_LOG}"

log "[host] running server setup inside VM..."
set +e
vagrant ssh "${CONTROL_NAME}" -c "sudo NODE_IP='${NODE_IP}' K3S_VERSION='${K3S_VERSION}' /vagrant/scripts/k3s/server-node-setup.sh" \
  2>&1 | tee -a "${INSTALL_LOG}"
RC=${PIPESTATUS[0]}
set -e

log ""
log "[host] collecting status + journal..."
vagrant ssh "${CONTROL_NAME}" -c "sudo systemctl --no-pager -l status k3s || true" \
  2>&1 | tee "${STATUS_LOG}"
vagrant ssh "${CONTROL_NAME}" -c "sudo journalctl -u k3s -n 250 --no-pager || true" \
  2>&1 | tee "${JOURNAL_LOG}"

log "[host] debug snapshot..."
vagrant ssh "${CONTROL_NAME}" -c "sudo /vagrant/scripts/k3s/debug-snapshot.sh || true" \
  2>&1 | tee "${DEBUG_LOG}"

if [[ ${RC} -ne 0 ]]; then
  log ""
  log "[host] FAIL: server-node-setup exited ${RC}"
  log "[host] logs:"
  log "  ${INSTALL_LOG}"
  log "  ${STATUS_LOG}"
  log "  ${JOURNAL_LOG}"
  log "  ${DEBUG_LOG}"
  exit "${RC}"
fi

log ""
log "[host] SUCCESS."
log "[host] logs:"
log "  ${INSTALL_LOG}"
log "  ${STATUS_LOG}"
log "  ${JOURNAL_LOG}"
log "  ${DEBUG_LOG}"