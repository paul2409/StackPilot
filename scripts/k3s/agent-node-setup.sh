# FILE: scripts/k3s/agent-node-setup.sh
#!/usr/bin/env bash
set -euo pipefail

# VM-side: installs k3s agent.
# - uses your local pinned binary
# - forces node-ip
# - auto-detect flannel iface by NODE_IP (prevents NAT public-ip bug)
# - sysctls + FORWARD ACCEPT + disables ufw

NODE_IP="${NODE_IP:?set NODE_IP, e.g. 192.168.56.11}"
SERVER_URL="${SERVER_URL:-https://192.168.56.10:6443}"
K3S_TOKEN="${K3S_TOKEN:?set K3S_TOKEN (from control node-token)}"
K3S_VERSION="${K3S_VERSION:-v1.34.4+k3s1}"

BIN_SRC="${BIN_SRC:-/vagrant/vagrant/k3s-bin/k3s}"
K3S_BIN_DST="${K3S_BIN_DST:-/usr/local/bin/k3s}"

echo "[agent-setup] node_ip=${NODE_IP}"
echo "[agent-setup] server_url=${SERVER_URL}"
echo "[agent-setup] k3s_version=${K3S_VERSION}"
echo "[agent-setup] bin_src=${BIN_SRC}"

if [[ ! -f "${BIN_SRC}" ]]; then
  echo "[agent-setup] ERROR: k3s binary not found at ${BIN_SRC}"
  exit 1
fi

echo "[agent-setup] preflight: swapoff, modules, sysctls, forwarding, ufw..."
sudo bash -lc '
set -euo pipefail
swapoff -a || true
sed -i.bak "/ swap / s/^/#/" /etc/fstab || true

modprobe br_netfilter 2>/dev/null || true

cat >/etc/sysctl.d/99-k8s.conf <<EOF
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
EOF
sysctl --system >/dev/null || true

iptables -P FORWARD ACCEPT 2>/dev/null || true
systemctl disable --now ufw 2>/dev/null || true
'

echo "[agent-setup] detect flannel iface by NODE_IP..."
FLANNEL_IFACE="$(ip -o -4 addr show | awk -v ip="${NODE_IP}" '$4 ~ ip {print $2; exit}')"
if [[ -z "${FLANNEL_IFACE}" ]]; then
  echo "[agent-setup] FATAL: could not detect interface that owns ${NODE_IP}"
  ip -br -4 addr
  exit 1
fi
echo "[agent-setup] flannel_iface=${FLANNEL_IFACE}"

echo "[agent-setup] installing binary..."
sudo install -m 0755 "${BIN_SRC}" "${K3S_BIN_DST}"
sudo ln -sf "${K3S_BIN_DST}" /usr/local/bin/kubectl
sudo ln -sf "${K3S_BIN_DST}" /usr/local/bin/crictl

echo "[agent-setup] writing systemd unit..."
sudo tee /etc/systemd/system/k3s-agent.service >/dev/null <<EOF
[Unit]
Description=K3s Agent (${K3S_VERSION})
Wants=network-online.target
After=network-online.target

[Service]
Type=exec
Environment="K3S_URL=${SERVER_URL}"
Environment="K3S_TOKEN=${K3S_TOKEN}"
ExecStart=${K3S_BIN_DST} agent \\
  --node-ip=${NODE_IP} \\
  --flannel-iface=${FLANNEL_IFACE}
Restart=always
RestartSec=5s
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

echo "[agent-setup] enable + start..."
sudo systemctl daemon-reload
sudo systemctl enable --now k3s-agent

echo "[agent-setup] agent status:"
sudo systemctl --no-pager -l status k3s-agent || true