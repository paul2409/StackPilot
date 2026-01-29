#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# StackPilot - Simple Provision: baseline tools + Docker + Compose
#
# Goal:
# - Install baseline tools used by StackPilot
# - Install Docker Engine from Ubuntu repo (stable in Vagrant)
# - Install docker-compose (v1) from Ubuntu repo
# - Provide ONE compose command: `docker compose` (shim -> docker-compose)
#
# Why this is simple + reliable:
# - No Docker apt repo
# - No GPG key setup
# - No IPv6/IPv4 forcing
# - Works on Ubuntu 22.04 Vagrant boxes
# ==========================================================

stage(){ echo "== $1 =="; }

export DEBIAN_FRONTEND=noninteractive

stage "APT update"
sudo apt-get update -y

stage "Baseline tools"
sudo apt-get install -y \
  ca-certificates curl jq git make \
  net-tools iputils-ping dnsutils

stage "Install Docker + Compose (Ubuntu repo)"
sudo apt-get install -y docker.io docker-compose

stage "Enable and start Docker"
sudo systemctl enable --now containerd
sudo systemctl enable --now docker.socket
sudo systemctl start docker

stage "Create docker compose shim (so your scripts can use: docker compose)"
if ! docker compose version >/dev/null 2>&1; then
  sudo tee /usr/local/bin/docker-compose-shim >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /usr/bin/docker-compose "$@"
EOF
  sudo chmod +x /usr/local/bin/docker-compose-shim

  # Create a small wrapper so `docker compose ...` works even without the v2 plugin.
  # This is a hack, but it's dependable for a lab.
  sudo tee /usr/local/bin/docker >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# If user runs "docker compose ...", route to docker-compose v1
if [ "${1:-}" = "compose" ]; then
  shift
  exec /usr/local/bin/docker-compose-shim "$@"
fi

# Otherwise call real docker binary
exec /usr/bin/docker "$@"
EOF
  sudo chmod +x /usr/local/bin/docker
fi

# ----------------------------------------------------------
# Docker: enable daemon + allow non-root docker for vagrant
# ----------------------------------------------------------
echo "== Docker: enable service and grant vagrant access =="

sudo systemctl enable --now docker

# Create docker group if it doesn't exist (safe)
if ! getent group docker >/dev/null 2>&1; then
  sudo groupadd docker
fi

# Add vagrant user to docker group (safe if already a member)
if id -nG vagrant | tr ' ' '\n' | grep -qx docker; then
  echo "INFO: vagrant already in docker group"
else
  sudo usermod -aG docker vagrant
  echo "INFO: added vagrant to docker group"
fi

# Make the socket permissions visible in logs (debug-proof)
echo "INFO: docker.sock perms:"
ls -l /var/run/docker.sock || true

echo "IMPORTANT: group changes require a new login shell."
echo "ACTION: exit VM and re-SSH (or reboot VM) before running docker/compose without sudo."

stage "Sanity"
sudo docker version >/dev/null
sudo docker ps >/dev/null

echo "DONE: baseline tools + docker installed"
echo "NOTE: 'vagrant' user may need re-login for docker group changes if you add them later."