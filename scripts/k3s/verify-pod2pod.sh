#!/usr/bin/env bash
set -euo pipefail

# Cross-node pod-to-pod connectivity proof:
# - Create nginx pod pinned to worker1
# - Create busybox pod pinned to worker2
# - From busybox: ping nginx POD_IP and curl nginx on POD_IP:80
# - Also checks DNS via kube-dns

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VAGRANT_DIR="${ROOT_DIR}/vagrant"
CONTROL_NAME="${CONTROL_NAME:-control}"

NS="${NS:-default}"
NGINX_POD="${NGINX_POD:-p2p-nginx-w1}"
BUSY_POD="${BUSY_POD:-p2p-busy-w2}"

NODE_W1="${NODE_W1:-worker1}"
NODE_W2="${NODE_W2:-worker2}"

log() { echo "[p2p] $*"; }

cd "${VAGRANT_DIR}"

K="vagrant ssh ${CONTROL_NAME} -c"

log "preflight: cluster nodes"
$K "sudo kubectl get nodes -o wide"

log "cleanup any previous run (ignore errors)"
$K "sudo kubectl -n ${NS} delete pod ${NGINX_POD} --ignore-not-found=true"
$K "sudo kubectl -n ${NS} delete pod ${BUSY_POD} --ignore-not-found=true"

log "create nginx pod on ${NODE_W1}"
$K "sudo kubectl -n ${NS} apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: ${NGINX_POD}
  labels:
    app: p2p-nginx
spec:
  nodeSelector:
    kubernetes.io/hostname: ${NODE_W1}
  containers:
  - name: nginx
    image: nginx:1.25
    ports:
    - containerPort: 80
YAML"

log "create busybox pod on ${NODE_W2} (sleep loop)"
$K "sudo kubectl -n ${NS} apply -f - <<'YAML'
apiVersion: v1
kind: Pod
metadata:
  name: ${BUSY_POD}
spec:
  nodeSelector:
    kubernetes.io/hostname: ${NODE_W2}
  containers:
  - name: bb
    image: busybox:1.36
    command: ['sh','-c','sleep 3600']
    securityContext:
      allowPrivilegeEscalation: false
YAML"

log "wait for nginx Ready"
$K "sudo kubectl -n ${NS} wait --for=condition=Ready pod/${NGINX_POD} --timeout=180s"

log "wait for busybox Ready"
$K "sudo kubectl -n ${NS} wait --for=condition=Ready pod/${BUSY_POD} --timeout=180s"

log "get nginx pod IP"
NGINX_IP="$($K "sudo kubectl -n ${NS} get pod ${NGINX_POD} -o jsonpath='{.status.podIP}'" | tr -d '\r')"
if [[ -z "${NGINX_IP}" ]]; then
  log "ERROR: nginx pod IP is empty"
  $K "sudo kubectl -n ${NS} get pod -o wide"
  exit 1
fi
log "nginx pod ip = ${NGINX_IP}"

log "show pod placement"
$K "sudo kubectl -n ${NS} get pod -o wide | egrep 'NAME|${NGINX_POD}|${BUSY_POD}'"

log "TEST 1: busybox -> nginx pod IP ping"
$K "sudo kubectl -n ${NS} exec ${BUSY_POD} -c bb -- sh -lc 'ping -c 3 ${NGINX_IP}'"

log "TEST 2: busybox -> nginx pod IP HTTP (curl via wget)"
$K "sudo kubectl -n ${NS} exec ${BUSY_POD} -c bb -- sh -lc 'wget -qO- http://${NGINX_IP}:80 | head -n 2'"

log "TEST 3: DNS from busybox (kubernetes.default)"
$K "sudo kubectl -n ${NS} exec ${BUSY_POD} -c bb -- sh -lc 'nslookup kubernetes.default.svc.cluster.local'"

log "SUCCESS: cross-node pod->pod + HTTP + DNS verified"

log "cleanup (optional): delete pods"
$K "sudo kubectl -n ${NS} delete pod ${NGINX_POD} --ignore-not-found=true"
$K "sudo kubectl -n ${NS} delete pod ${BUSY_POD} --ignore-not-found=true"

log "done"