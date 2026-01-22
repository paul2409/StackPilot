#!/usr/bin/env bash
# Use bash to run this script

set -e
# Exit immediately if any command fails (prevents silent errors)

echo "[1/6] Updating packages..."
# Update the package index so apt knows about the latest available packages
sudo apt-get update -y

echo "[2/6] Installing Docker prerequisites..."
# Install basic packages needed to securely add external repositories
sudo apt-get update -y
sudo apt-get install -y ca-certificates curl gnupg lsb-release

echo "[3/6] Installing ops tools (debug toolkit)..."
# Install common operational/debugging tools used throughout the project
sudo apt-get install -y jq git net-tools iproute2 lsof dnsutils tcpdump

echo "[4/6] Installing Docker Engine + Compose plugin..."
# Stop Docker if it is already running (ignore errors if not installed)
sudo systemctl stop docker 2>/dev/null || true

# Remove old or conflicting container packages that can break Docker Engine
sudo apt-get remove -y \
  docker.io \
  docker-doc \
  docker-compose \
  docker-compose-v2 \
  podman-docker \
  runc \
  containerd || true

# Clean up unused packages after removal
sudo apt-get autoremove -y

# Create directory to store trusted GPG keys for apt repositories
sudo install -m 0755 -d /etc/apt/keyrings

# Download Docker’s official GPG key if it does not already exist
if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
fi

# Detect Ubuntu codename (e.g. jammy for 22.04)
CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-jammy}")"

# Add Docker’s official APT repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Refresh package list now that Docker repo is added
sudo apt-get update -y

# Install Docker Engine, CLI, container runtime, and Compose plugin
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-buildx-plugin \
  docker-compose-plugin

echo "[5/6] Starting Docker..."
# Enable Docker to start on boot and start it immediately
sudo systemctl enable --now docker

echo "[6/6] Allowing vagrant user to run docker (no sudo)..."
# Add the vagrant user to the docker group so sudo is not required
sudo usermod -aG docker vagrant || true

echo "Done."
echo "IMPORTANT: exit and re-SSH for docker group to apply."
echo "You can verify Docker is working by running: docker version"
echo "Then run: docker run hello-world"