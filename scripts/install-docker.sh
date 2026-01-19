#!/usr/bin/env bash
set -e

# Skip if Docker already exists
if command -v docker >/dev/null 2>&1; then
  echo "Docker already installed"
  exit 0
fi

echo "Installing Docker..."

sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg lsb-release

curl -fsSL https://get.docker.com | sudo sh

# Allow vagrant user to run docker without sudo
sudo usermod -aG docker vagrant

echo "Docker installation complete"
