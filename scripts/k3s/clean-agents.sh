#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 <worker1> [worker2 ...]"
}

log(){ echo "[clean] $*"; }
die(){ echo "[clean] ERROR: $*" >&2; exit 1; }

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

# Locate repo root and vagrant dir reliably
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VAGRANT_DIR="$REPO_ROOT/vagrant"

[[ -f "$VAGRANT_DIR/Vagrantfile" ]] || die "Vagrantfile not found at: $VAGRANT_DIR/Vagrantfile"

cd "$VAGRANT_DIR"
log "running from: $PWD"

for node in "$@"; do
  log "node=$node"

  # (1) stop services (even if they "don't exist")
  log "1) stop services (ignore missing)"
  vagrant ssh "$node" -c "sudo bash -lc ' \
    systemctl stop k3s-agent 2>/dev/null || true; \
    systemctl stop k3s 2>/dev/null || true; \
    systemctl stop kubelet 2>/dev/null || true; \
    pkill -f \"k3s agent\" 2>/dev/null || true; \
    pkill -f \"k3s server\" 2>/dev/null || true; \
    pkill -f kubelet 2>/dev/null || true; \
    pkill -f k3s 2>/dev/null || true; \
    sleep 2 \
  '"

  # (2) unmount anything under kubelet pods (usually what blocks deletion)
  log "2) unmount anything under /var/lib/kubelet/pods"
  vagrant ssh "$node" -c "sudo bash -lc ' \
    set +e; \
    if command -v findmnt >/dev/null 2>&1; then \
      for t in \$(findmnt -R /var/lib/kubelet/pods -n -o TARGET 2>/dev/null | sort -r); do \
        umount -l \"\$t\" 2>/dev/null || true; \
      done; \
    fi; \
    mount | awk \"\\\$3 ~ \\\"^/var/lib/kubelet/pods/\\\" {print \\\$3}\" | sort -r | while read -r t; do \
      umount -l \"\$t\" 2>/dev/null || true; \
    done; \
    true \
  '"

  # (3) wipe state dirs + remove unit files
  log "3) wipe state dirs"
  vagrant ssh "$node" -c "sudo bash -lc ' \
    rm -rf /var/lib/kubelet/pods 2>/dev/null || true; \
    rm -rf /var/lib/kubelet 2>/dev/null || true; \
    rm -rf /var/lib/rancher/k3s 2>/dev/null || true; \
    rm -rf /etc/rancher 2>/dev/null || true; \
    rm -rf /var/lib/cni 2>/dev/null || true; \
    rm -rf /etc/cni 2>/dev/null || true; \
    rm -f /etc/systemd/system/k3s-agent.service /etc/systemd/system/k3s-agent.service.env 2>/dev/null || true; \
    rm -f /etc/systemd/system/k3s.service /etc/systemd/system/k3s.service.env 2>/dev/null || true; \
    systemctl daemon-reload 2>/dev/null || true; \
    ip link delete cni0 2>/dev/null || true; \
    ip link delete flannel.1 2>/dev/null || true; \
    true \
  '"

  # (4) reboot the node to guarantee mounts are gone
  log "4) reboot node (vagrant reload) => $node"
  vagrant reload "$node"

  log "$node cleaned"
done

log "done. next: run your install script to rejoin agents."