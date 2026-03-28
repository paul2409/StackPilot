#!/usr/bin/env bash
set -euo pipefail

VAGRANT_DIR="${VAGRANT_DIR:-vagrant}"

cd "${VAGRANT_DIR}"

echo "[cluster-up] ensuring VMs are up..."
vagrant up

echo "[cluster-up] installing server on control..."
vagrant ssh control -c "bash /vagrant/vagrant/scripts/k3s/server-install.sh" | tee /tmp/k3s-server.log

# Extract token from output (last line is token in our script)
TOKEN="$(tail -n 1 /tmp/k3s-server.log | tr -d '\r')"
if [[ -z "${TOKEN}" ]]; then
  echo "[cluster-up] ERROR: could not extract token"
  exit 1
fi
echo "[cluster-up] token extracted."

echo "[cluster-up] installing agent on worker1..."
vagrant ssh worker1 -c "TOKEN=${TOKEN} SERVER_IP=192.168.56.10 NODE_IP=192.168.56.11 bash /vagrant/vagrant/scripts/k3s/agent-install.sh"

echo "[cluster-up] installing agent on worker2..."
vagrant ssh worker2 -c "TOKEN=${TOKEN} SERVER_IP=192.168.56.10 NODE_IP=192.168.56.12 bash /vagrant/vagrant/scripts/k3s/agent-install.sh"

echo "[cluster-up] final nodes:"
vagrant ssh control -c "sudo kubectl get nodes -o wide"