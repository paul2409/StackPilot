#!/usr/bin/env bash
set -euo pipefail

# scripts/k3s/reset-all.sh
# Host-side: best-effort cleanup for k3s on control + workers.
# Order:
#  1) Ensure VMs up
#  2) If API is up, delete worker node objects (best-effort)
#  3) Uninstall agents on workers
#  4) Uninstall server on control
#  5) Extra cleanup: CNI links + leftover dirs

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VAGRANT_DIR="${ROOT_DIR}/vagrant"

CONTROL_NAME="${CONTROL_NAME:-control}"
WORKERS_DEFAULT=("worker1" "worker2")

# Allow override: export WORKERS="worker1 worker2"
if [[ -n "${WORKERS:-}" ]]; then
  # shellcheck disable=SC2206
  WORKERS_ARR=(${WORKERS})
else
  WORKERS_ARR=("${WORKERS_DEFAULT[@]}")
fi

cd "${VAGRANT_DIR}"

echo "[reset] bringing up VMs (if needed)..."
vagrant up "${CONTROL_NAME}" "${WORKERS_ARR[@]}"

echo "[reset] best-effort: delete worker node objects while API is still up..."
vagrant ssh "${CONTROL_NAME}" -c "sudo bash -lc '
set -euo pipefail
if command -v kubectl >/dev/null 2>&1 && kubectl version --request-timeout=3s >/dev/null 2>&1; then
  kubectl delete node ${WORKERS_ARR[*]} --ignore-not-found=true || true
else
  echo \"[control] API not reachable right now (ok)\"
fi
' " || true

echo "[reset] uninstalling k3s from workers..."
for w in "${WORKERS_ARR[@]}"; do
  echo "  -> ${w}"
  vagrant ssh "${w}" -c "sudo bash -lc '
set -euo pipefail

# Stop services if present
systemctl disable --now k3s-agent 2>/dev/null || true
systemctl disable --now k3s 2>/dev/null || true

# Prefer official uninstall script if it exists
if [[ -x /usr/local/bin/k3s-agent-uninstall.sh ]]; then
  /usr/local/bin/k3s-agent-uninstall.sh || true
fi

# If you used custom units, remove them
rm -f /etc/systemd/system/k3s-agent.service || true
rm -f /etc/systemd/system/k3s.service || true
systemctl daemon-reload || true

# Clean leftover state (targeted)
rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /var/lib/cni /etc/cni /opt/cni /run/flannel /run/k3s || true

# Remove leftover CNI interfaces (common after crashes)
ip link del cni0 2>/dev/null || true
ip link del flannel.1 2>/dev/null || true
ip link del kube-ipvs0 2>/dev/null || true

echo \"[worker] done\"
' "
done

echo "[reset] uninstalling k3s from control..."
vagrant ssh "${CONTROL_NAME}" -c "sudo bash -lc '
set -euo pipefail

systemctl disable --now k3s 2>/dev/null || true

if [[ -x /usr/local/bin/k3s-uninstall.sh ]]; then
  /usr/local/bin/k3s-uninstall.sh || true
fi

rm -f /etc/systemd/system/k3s.service || true
systemctl daemon-reload || true

rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet /var/lib/cni /etc/cni /opt/cni /run/flannel /run/k3s || true

ip link del cni0 2>/dev/null || true
ip link del flannel.1 2>/dev/null || true
ip link del kube-ipvs0 2>/dev/null || true

echo \"[control] done\"
' "

echo "[reset] DONE. Next step: run your install-server.sh then install-agents.sh"