#!/usr/bin/env bash
set -euo pipefail

# FILE: scripts/k3s/install-agent.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VAGRANT_DIR="${ROOT_DIR}/vagrant"

CONTROL_NAME="${CONTROL_NAME:-control}"
SERVER_IP="${SERVER_IP:-192.168.56.10}"
SERVER_URL="${SERVER_URL:-https://${SERVER_IP}:6443}"
K3S_VERSION="${K3S_VERSION:-v1.34.4+k3s1}"

WORKER1_IP="${WORKER1_IP:-192.168.56.11}"
WORKER2_IP="${WORKER2_IP:-192.168.56.12}"

if [[ $# -gt 0 ]]; then
  TARGET_NODES="$*"
else
  TARGET_NODES="${TARGET_NODES:-worker1 worker2}"
fi

LOG_DIR="${ROOT_DIR}/artifacts/logs/k3s"
mkdir -p "${LOG_DIR}"
TS="$(date +%Y%m%d-%H%M%S)"
INSTALL_LOG="${LOG_DIR}/install-agent-${TS}.log"

log() { echo "$*" | tee -a "${INSTALL_LOG}"; }
: > "${INSTALL_LOG}"

node_ip_for() {
  case "$1" in
    worker1) echo "${WORKER1_IP}" ;;
    worker2) echo "${WORKER2_IP}" ;;
    *) echo "" ;;
  esac
}

cd "${VAGRANT_DIR}"

log "[host] control=${CONTROL_NAME} server_url=${SERVER_URL} k3s_version=${K3S_VERSION}"
log "[host] target_nodes='${TARGET_NODES}'"
log "[host] log=${INSTALL_LOG}"
log ""

log "[host] ensuring control VM is up..."
vagrant up "${CONTROL_NAME}" 2>&1 | tee -a "${INSTALL_LOG}"

log "[host] fetching join token from control..."
TOKEN="$(vagrant ssh "${CONTROL_NAME}" -c "sudo cat /var/lib/rancher/k3s/server/node-token" 2>/dev/null | tr -d '\r' | tail -n1)"
if [[ -z "${TOKEN}" ]]; then
  log "[host] FATAL: could not fetch join token from control"
  exit 1
fi
log "[host] token: ok"
log ""

for TARGET_NODE in ${TARGET_NODES}; do
  NODE_IP="$(node_ip_for "${TARGET_NODE}")"
  if [[ -z "${NODE_IP}" ]]; then
    log "[host] FATAL: unknown node '${TARGET_NODE}'. expected worker1/worker2"
    exit 1
  fi

  log "============================================================"
  log "[host] target=${TARGET_NODE} node_ip=${NODE_IP}"
  log "============================================================"

  log "[host] ensuring VM is up: ${TARGET_NODE}"
  vagrant up "${TARGET_NODE}" 2>&1 | tee -a "${INSTALL_LOG}"

  log "[host] preflight network inside ${TARGET_NODE} (dns + ping)..."
  vagrant ssh "${TARGET_NODE}" -c "sudo bash -lc 'set -e;
    if getent hosts registry-1.docker.io >/dev/null 2>&1; then
      echo DNS_OK;
    else
      echo DNS_FAIL;
    fi
    if ping -c 1 -W 2 ${SERVER_IP} >/dev/null 2>&1; then
      echo PING_OK;
    else
      echo PING_FAIL;
    fi
  '" 2>&1 | tee -a "${INSTALL_LOG}"

  log "[host] installing agent inside ${TARGET_NODE}..."
  set +e
  sed 's/\r$//' "${ROOT_DIR}/scripts/k3s/agent-node-setup.sh" | \
    vagrant ssh "${TARGET_NODE}" -c "sudo env NODE_IP='${NODE_IP}' SERVER_URL='${SERVER_URL}' K3S_TOKEN='${TOKEN}' K3S_VERSION='${K3S_VERSION}' bash -s" \
    2>&1 | tee -a "${INSTALL_LOG}"
  RC=${PIPESTATUS[1]}
  set -e

  if [[ ${RC} -ne 0 ]]; then
    log "[host] FAIL: agent-node-setup failed on ${TARGET_NODE} (rc=${RC})"
    log "[host] check inside VM:"
    log "  vagrant ssh ${TARGET_NODE} -c \"sudo systemctl status k3s-agent --no-pager -l\""
    log "  vagrant ssh ${TARGET_NODE} -c \"sudo journalctl -u k3s-agent -n 200 --no-pager\""
    exit "${RC}"
  fi

  log "[host] verify nodes from control:"
  vagrant ssh "${CONTROL_NAME}" -c "sudo k3s kubectl get nodes -o wide" 2>&1 | tee -a "${INSTALL_LOG}"
  log ""
done

log "[host] SUCCESS. all target nodes attempted."