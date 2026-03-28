#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VAGRANT_DIR="${ROOT_DIR}/vagrant"

FRESH=0
if [[ "${1:-}" == "--fresh" ]]; then
  FRESH=1
fi

log() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*"
}

err() {
  printf '[ERROR] %s\n' "$*" >&2
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "Required command not found: $1"
    exit 1
  }
}

require_cmd vagrant
require_cmd powershell.exe
require_cmd ping

cd "$VAGRANT_DIR"

declare -A NODE_IPS=(
  [control]="192.168.56.10"
  [worker1]="192.168.56.11"
  [worker2]="192.168.56.12"
)

VM_NAMES=(
  "stackpilot-control"
  "stackpilot-worker1"
  "stackpilot-worker2"
)

INTERNET_SWITCH="Default Switch"
ADAPTER_NAME="internet"

if [[ "$FRESH" -eq 1 ]]; then
  log "Fresh rebuild requested..."
  vagrant destroy -f || true
fi

log "Step 1: Create VMs without provisioning..."
vagrant up --no-provision

log "Step 2: Stop VMs so Hyper-V can modify hardware..."
vagrant halt

log "Step 3: Add internet NICs in Hyper-V..."
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "
\$ErrorActionPreference = 'Stop'

\$vmNames = @('stackpilot-control','stackpilot-worker1','stackpilot-worker2')
\$internetSwitch = 'Default Switch'
\$adapterName = 'internet'

foreach (\$vm in \$vmNames) {
  \$existing = Get-VMNetworkAdapter -VMName \$vm -ErrorAction SilentlyContinue |
    Where-Object { \$_.Name -eq \$adapterName }

  if (-not \$existing) {
    Write-Host \"[INFO] Adding adapter '\$adapterName' to \$vm on '\$internetSwitch'...\"
    Add-VMNetworkAdapter -VMName \$vm -SwitchName \$internetSwitch -Name \$adapterName
  } else {
    Write-Host \"[INFO] \$vm already has adapter '\$adapterName'. Skipping.\"
  }
}

Write-Host '[INFO] Current VM NIC layout:'
foreach (\$vm in \$vmNames) {
  Write-Host \"----- \$vm -----\"
  Get-VMNetworkAdapter -VMName \$vm |
    Select-Object VMName, Name, SwitchName, Status |
    Format-Table -AutoSize
}
"

log "Step 4: Start VMs again without provisioning..."
vagrant up --no-provision

configure_guest_network() {
  local vm_name="$1"
  local lab_ip="$2"

  log "Configuring guest networking on ${vm_name}..."

  vagrant ssh "$vm_name" -c "sudo bash -s" <<EOF
set -euo pipefail

LAB_IP="${lab_ip}"
NETPLAN_FILE="/etc/netplan/60-stackpilot.yaml"

echo "[INFO] Initial interfaces:"
ip -br link
echo "---"
ip -4 addr || true
echo "---"
ip route || true
echo "---"

mapfile -t IFACES < <(
  ip -o link show | awk -F': ' '{print \$2}' | cut -d@ -f1 | grep -v '^lo$'
)

if [[ "\${#IFACES[@]}" -lt 2 ]]; then
  echo "[ERROR] Expected at least 2 non-loopback interfaces, found \${#IFACES[@]}"
  ip -br link
  exit 1
fi

echo "[INFO] Candidate interfaces: \${IFACES[*]}"

for iface in "\${IFACES[@]}"; do
  ip link set "\$iface" up || true
done

wait_for_interface_ready() {
  local iface="\$1"
  local tries=8
  local i

  for ((i=1; i<=tries; i++)); do
    local state
    state="\$(cat /sys/class/net/\$iface/operstate 2>/dev/null || echo unknown)"
    echo "[INFO] \$iface operstate: \$state (attempt \$i/\$tries)"
    if [[ "\$state" == "up" || "\$state" == "unknown" ]]; then
      return 0
    fi
    sleep 2
  done

  return 1
}

get_default_iface() {
  ip route | awk '/^default / {print \$5; exit}'
}

INTERNET_IF=""
LAB_IF=""

echo "[INFO] Detecting internet interface..."
for iface in "\${IFACES[@]}"; do
  echo "[INFO] Checking \$iface ..."
  ip link set "\$iface" up || true

  if ! wait_for_interface_ready "\$iface"; then
    echo "[WARN] \$iface did not become ready in time, skipping DHCP probe"
    continue
  fi

  dhclient -r "\$iface" >/dev/null 2>&1 || true
  timeout 10 dhclient -1 "\$iface" >/dev/null 2>&1 || true

  DEFAULT_IF="\$(get_default_iface || true)"
  if [[ "\$DEFAULT_IF" == "\$iface" ]]; then
    INTERNET_IF="\$iface"
    echo "[INFO] Selected internet interface: \$INTERNET_IF"
    break
  fi
done

if [[ -z "\$INTERNET_IF" ]]; then
  echo "[ERROR] Could not determine internet interface"
  echo "[DEBUG] ip -br link:"
  ip -br link || true
  echo "---"
  echo "[DEBUG] ip -4 addr:"
  ip -4 addr || true
  echo "---"
  echo "[DEBUG] ip route:"
  ip route || true
  exit 1
fi

for iface in "\${IFACES[@]}"; do
  if [[ "\$iface" != "\$INTERNET_IF" ]]; then
    LAB_IF="\$iface"
    break
  fi
done

if [[ -z "\$LAB_IF" ]]; then
  echo "[ERROR] Could not determine lab interface"
  exit 1
fi

echo "[INFO] INTERNET_IF=\$INTERNET_IF"
echo "[INFO] LAB_IF=\$LAB_IF"

ip link set "\$LAB_IF" up || true
ip link set "\$INTERNET_IF" up || true

# Do not flush the lab interface during a live Vagrant SSH session.
# Just ensure the desired IPv4 is present.
if ! ip -4 addr show dev "\$LAB_IF" | grep -q "\$LAB_IP/24"; then
  ip addr add "\$LAB_IP/24" dev "\$LAB_IF"
fi

cat > "\$NETPLAN_FILE" <<NETPLAN
network:
  version: 2
  renderer: networkd
  ethernets:
    \$LAB_IF:
      dhcp4: false
      dhcp6: false
      addresses:
        - \$LAB_IP/24
    \$INTERNET_IF:
      dhcp4: true
      dhcp6: false
NETPLAN

chmod 600 "\$NETPLAN_FILE"

echo "[INFO] Written netplan:"
cat "\$NETPLAN_FILE"
echo "---"

netplan generate

# Apply in background so a brief SSH disruption does not kill the session.
nohup bash -c 'sleep 2; netplan apply' >/tmp/stackpilot-netplan-apply.log 2>&1 &
sleep 6

echo "[INFO] Final interface state:"
ip -br addr || true
echo "---"
echo "[INFO] Final routes:"
ip route || true
EOF
}

verify_guest_network() {
  local vm_name="$1"
  local expected_ip="$2"

  log "Verifying guest networking on ${vm_name}..."

  vagrant ssh "$vm_name" -c "ip -4 -br addr && echo --- && ip route" || {
    err "Failed to inspect networking inside ${vm_name}"
    exit 1
  }

  vagrant ssh "$vm_name" -c "ip -4 addr | grep -q '${expected_ip}/24'" || {
    err "${vm_name} does not have expected lab IP ${expected_ip}/24"
    exit 1
  }
}

log "Step 5: Configure guest networking..."
configure_guest_network "control" "${NODE_IPS[control]}"
configure_guest_network "worker1" "${NODE_IPS[worker1]}"
configure_guest_network "worker2" "${NODE_IPS[worker2]}"

log "Step 6: Verify guest-side addressing..."
verify_guest_network "control" "${NODE_IPS[control]}"
verify_guest_network "worker1" "${NODE_IPS[worker1]}"
verify_guest_network "worker2" "${NODE_IPS[worker2]}"

log "Step 7: Verify host-to-VM connectivity..."
for ip in "${NODE_IPS[control]}" "${NODE_IPS[worker1]}" "${NODE_IPS[worker2]}"; do
  printf '[INFO] Pinging %s ...\n' "$ip"
  ping -n 2 "$ip" >/dev/null 2>&1 || {
    err "Host cannot reach $ip"
    exit 1
  }
done

log "Step 8: Run provisioning..."
vagrant provision

log "Done."