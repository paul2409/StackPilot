#!/usr/bin/env bash
set -euo pipefail

# scripts/k3s/server-node-setup.sh
# VM-side: installs k3s server from a pinned binary and starts systemd unit.
# This version:
# - disables Traefik
# - removes old Traefik resources if present
# - installs ingress-nginx instead
# - keeps all kubectl calls bounded with timeouts

NODE_IP="${NODE_IP:-192.168.56.10}"
K3S_VERSION="${K3S_VERSION:-v1.34.4+k3s1}"

BIN_SRC="${BIN_SRC:-/vagrant/vagrant/k3s-bin/k3s}"
K3S_BIN_DST="${K3S_BIN_DST:-/usr/local/bin/k3s}"

KUBECTL_TIMEOUT="${KUBECTL_TIMEOUT:-5s}"
WAIT_API_SECONDS="${WAIT_API_SECONDS:-180}"
WAIT_NODE_SECONDS="${WAIT_NODE_SECONDS:-180}"
WAIT_INGRESS_SECONDS="${WAIT_INGRESS_SECONDS:-240}"

INGRESS_NGINX_MANIFEST_URL="${INGRESS_NGINX_MANIFEST_URL:-https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.3/deploy/static/provider/baremetal/deploy.yaml}"

echo "[server-setup] node_ip=${NODE_IP}"
echo "[server-setup] k3s_version=${K3S_VERSION}"
echo "[server-setup] bin_src=${BIN_SRC}"
echo "[server-setup] ingress_nginx_manifest=${INGRESS_NGINX_MANIFEST_URL}"

if [[ ! -f "${BIN_SRC}" ]]; then
  echo "[server-setup] ERROR: k3s binary not found at ${BIN_SRC}"
  exit 1
fi

fail_with_logs() {
  echo "[server-setup] FAIL: $*"
  echo "[server-setup] --- systemctl status k3s ---"
  sudo systemctl --no-pager -l status k3s || true
  echo "[server-setup] --- journalctl -u k3s (last 200) ---"
  sudo journalctl -u k3s -n 200 --no-pager || true
  echo "[server-setup] --- listening ports (6443) ---"
  sudo ss -lntp | grep 6443 || true
  echo "[server-setup] --- ingress-nginx pods ---"
  sudo kubectl --request-timeout="${KUBECTL_TIMEOUT}" -n ingress-nginx get pods -o wide || true
  exit 1
}

echo "[server-setup] preflight: swapoff, modules, sysctls, forwarding, ufw..."
sudo bash -lc '
set -euo pipefail

swapoff -a || true
sed -i.bak "/ swap / s/^/#/" /etc/fstab || true

modprobe br_netfilter 2>/dev/null || true

set_if_exists() {
  local key="$1" val="$2"
  if sysctl -a 2>/dev/null | grep -q "^${key} ="; then
    sysctl -w "${key}=${val}" >/dev/null 2>&1 || true
  fi
}

set_if_exists net.ipv4.ip_forward 1
set_if_exists net.bridge.bridge-nf-call-iptables 1
set_if_exists net.bridge.bridge-nf-call-ip6tables 1

iptables -P FORWARD ACCEPT 2>/dev/null || true
systemctl disable --now ufw 2>/dev/null || true
'

echo "[server-setup] detect flannel iface by NODE_IP..."
FLANNEL_IFACE="$(ip -o -4 addr show | awk -v ip="${NODE_IP}" '$4 ~ ip {print $2; exit}')"
if [[ -z "${FLANNEL_IFACE}" ]]; then
  echo "[server-setup] FATAL: could not detect interface that owns ${NODE_IP}"
  ip -br -4 addr || true
  exit 1
fi
echo "[server-setup] flannel_iface=${FLANNEL_IFACE}"

echo "[server-setup] removing old packaged Traefik manifests if present..."
sudo rm -f /var/lib/rancher/k3s/server/manifests/traefik.yaml || true
sudo rm -f /var/lib/rancher/k3s/server/manifests/traefik-config.yaml || true

echo "[server-setup] installing binary..."
sudo install -m 0755 "${BIN_SRC}" "${K3S_BIN_DST}"
sudo ln -sf "${K3S_BIN_DST}" /usr/local/bin/kubectl
sudo ln -sf "${K3S_BIN_DST}" /usr/local/bin/crictl

echo "[server-setup] writing systemd unit..."
sudo tee /etc/systemd/system/k3s.service >/dev/null <<EOF
[Unit]
Description=K3s Server (${K3S_VERSION})
Wants=network-online.target
After=network-online.target

[Service]
Type=exec
Environment="K3S_KUBECONFIG_MODE=644"
ExecStart=${K3S_BIN_DST} server \\
  --node-ip=${NODE_IP} \\
  --advertise-address=${NODE_IP} \\
  --tls-san=${NODE_IP} \\
  --flannel-iface=${FLANNEL_IFACE} \\
  --disable traefik \\
  --write-kubeconfig-mode 644
Restart=always
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

echo "[server-setup] enable + start..."
sudo systemctl daemon-reload
sudo systemctl enable --now k3s

k() {
  sudo kubectl --request-timeout="${KUBECTL_TIMEOUT}" "$@"
}

echo "[server-setup] wait for API (deadline ${WAIT_API_SECONDS}s)..."
end=$((SECONDS + WAIT_API_SECONDS))
until k version >/dev/null 2>&1; do
  if (( SECONDS > end )); then
    fail_with_logs "API not ready after ${WAIT_API_SECONDS}s"
  fi
  echo "[server-setup] ...still waiting for API"
  sleep 2
done
echo "[server-setup] API is responding."

echo "[server-setup] wait for node registration (deadline ${WAIT_NODE_SECONDS}s)..."
end=$((SECONDS + WAIT_NODE_SECONDS))
until k get nodes -o name 2>/dev/null | grep -q '^node/'; do
  if (( SECONDS > end )); then
    fail_with_logs "node not registered after ${WAIT_NODE_SECONDS}s"
  fi
  echo "[server-setup] ...still waiting for node registration"
  sleep 2
done

CONTROL_NODE_NAME="$(k get nodes -o name | head -n1 | sed 's#node/##')"
echo "[server-setup] control_node=${CONTROL_NODE_NAME}"

echo "[server-setup] apply control-plane NoSchedule taint..."
k taint nodes "${CONTROL_NODE_NAME}" node-role.kubernetes.io/control-plane=:NoSchedule --overwrite >/dev/null 2>&1 || true

echo "[server-setup] removing Traefik resources if present..."
k -n kube-system delete helmchart traefik --ignore-not-found || true
k -n kube-system delete helmchart traefik-crd --ignore-not-found || true
k -n kube-system delete deployment traefik --ignore-not-found || true
k -n kube-system delete service traefik --ignore-not-found || true
k delete ingressclass traefik --ignore-not-found || true
k delete validatingwebhookconfiguration traefik-ingress-controller-admission --ignore-not-found || true
k delete mutatingwebhookconfiguration traefik-ingress-controller-admission --ignore-not-found || true

echo "[server-setup] installing ingress-nginx..."
k apply -f "${INGRESS_NGINX_MANIFEST_URL}"

echo "[server-setup] wait for ingress-nginx controller rollout (deadline ${WAIT_INGRESS_SECONDS}s)..."
end=$((SECONDS + WAIT_INGRESS_SECONDS))
until k -n ingress-nginx rollout status deployment/ingress-nginx-controller --timeout="${KUBECTL_TIMEOUT}" >/dev/null 2>&1; do
  if (( SECONDS > end )); then
    fail_with_logs "ingress-nginx controller not ready after ${WAIT_INGRESS_SECONDS}s"
  fi
  echo "[server-setup] ...still waiting for ingress-nginx controller"
  sleep 3
done

echo "[server-setup] setting nginx as default ingress class..."
k patch ingressclass nginx --type merge -p '{"metadata":{"annotations":{"ingressclass.kubernetes.io/is-default-class":"true"}}}' >/dev/null 2>&1 || true

echo "[server-setup] final nodes:"
k get nodes -o wide || true

echo "[server-setup] ingress classes:"
k get ingressclass || true

echo "[server-setup] ingress-nginx workload:"
k -n ingress-nginx get pods,svc,deploy -o wide || true

echo "[server-setup] kube-dns endpoints:"
k -n kube-system get endpoints kube-dns -o wide || true

echo "[server-setup] flannel annotations:"
k get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.annotations.flannel\.alpha\.coreos\.com/public-ip}{"\t"}{.metadata.annotations.flannel\.alpha\.coreos\.com/backend-type}{"\n"}{end}' || true
echo ""

echo "[server-setup] join token:"
sudo cat /var/lib/rancher/k3s/server/node-token