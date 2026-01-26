#!/usr/bin/env bash
# StackPilot — Hardened Docker Install (Adaptive IPv6->IPv4 fallback)
#
# Why this script exists:
# - Some nodes (e.g., worker1) may have poisoned/bad IPv4 routing to download.docker.com
#   causing TLS/cert mismatch and "NO_PUBKEY" downstream.
# - Other nodes (e.g., control) may have flaky/unreachable IPv6 at times ("Connection refused").
#
# Therefore:
# - We do NOT hard-force IPv6 globally.
# - For Docker endpoints, we TRY IPv6 first (to avoid poisoned IPv4), then FALL BACK to IPv4.
# - We self-heal broken states where docker.list exists and breaks apt-get update.
# - We keep non-interactive safety (vagrant ssh -c): gpg uses --batch --yes.
# - We fail only when BOTH IPv6 and IPv4 paths fail.

set -euo pipefail

stage() { echo "[$1/8] $2"; }

DOCKER_LIST="/etc/apt/sources.list.d/docker.list"
DOCKER_LIST_DISABLED="/etc/apt/sources.list.d/docker.list.disabled"
DOCKER_KEY="/etc/apt/keyrings/docker.gpg"
DOCKER_GPG_URL="https://download.docker.com/linux/ubuntu/gpg"
DOCKER_REPO_BASE="https://download.docker.com/linux/ubuntu"

# -----------------------------
# Helper: fetch a URL with IPv6 preferred, IPv4 fallback
# -----------------------------
# Usage:
#   fetch_dualstack <url> <output_file>
#
# Behavior:
# - Try curl over IPv6 first (helps when IPv4 is poisoned)
# - If IPv6 fails, try IPv4 (helps when IPv6 is unavailable)
# - Logs which path was used
fetch_dualstack() {
  local url="$1"
  local out="$2"

  # Try IPv6 first
  if curl -6 -fsSL --max-time 15 "$url" -o "$out"; then
    echo "INFO: fetched over IPv6: $url"
    return 0
  fi

  # Fall back to IPv4
  if curl -4 -fsSL --max-time 15 "$url" -o "$out"; then
    echo "INFO: fetched over IPv4: $url"
    return 0
  fi

  echo "ERROR: failed to fetch over IPv6 and IPv4: $url"
  return 1
}

# -----------------------------
# [1/8] Self-heal: unblock base apt update
# -----------------------------
stage 1 "Self-heal: disable Docker repo before base apt update (if present)"

# If docker.list exists but its key/TLS path is broken, `apt-get update` can fail
# before we get a chance to fix it. Disable it temporarily.
if [ -f "$DOCKER_LIST" ]; then
  sudo mv -f "$DOCKER_LIST" "$DOCKER_LIST_DISABLED" || true
fi

# Clear cached apt metadata to avoid stale signature errors
sudo rm -rf /var/lib/apt/lists/*

# -----------------------------
# [2/8] Base apt update (Ubuntu repos only)
# -----------------------------
stage 2 "Base apt update (Ubuntu repos only)"

# Use system default network behavior here (don’t force v4/v6 globally).
sudo apt-get update -y

# -----------------------------
# [3/8] Install prerequisites
# -----------------------------
stage 3 "Install prerequisites (CA, curl, GPG, OS metadata)"

# Needed for secure repo setup and downloads:
sudo apt-get install -y ca-certificates curl gnupg lsb-release
sudo update-ca-certificates || true

# -----------------------------
# [4/8] Time sync (TLS sanity)
# -----------------------------
stage 4 "Ensure time sync (NTP)"

# TLS validation fails if clock is wrong.
sudo timedatectl set-ntp true || true
sudo systemctl restart systemd-timesyncd || true
sleep 2

# -----------------------------
# [5/8] Remove conflicting packages
# -----------------------------
stage 5 "Remove conflicting container packages (safe if missing)"

sudo systemctl stop docker 2>/dev/null || true

# Remove common conflicting packages safely (ignore errors if not installed).
sudo apt-get remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker runc containerd || true
sudo apt-get autoremove -y

# -----------------------------
# [6/8] Install Docker GPG key (dual-stack fetch)
# -----------------------------
stage 6 "Install Docker GPG key (prefer IPv6, fallback to IPv4; non-interactive safe)"

# Create modern keyrings dir
sudo install -m 0755 -d /etc/apt/keyrings

# Fetch the key into a temp file using adaptive network path.
# This avoids:
# - worker1 poisoned IPv4
# - control IPv6 connection refused
TMP_KEY="$(mktemp)"
trap 'rm -f "$TMP_KEY"' EXIT

fetch_dualstack "$DOCKER_GPG_URL" "$TMP_KEY"

# Convert ASCII-armored key to binary keyring for apt.
# --batch/--yes prevents gpg from trying to open /dev/tty in non-interactive runs.
sudo gpg --batch --yes --dearmor -o "$DOCKER_KEY" "$TMP_KEY"
sudo chmod a+r "$DOCKER_KEY"

# Fail fast if key is corrupt/empty
sudo gpg --show-keys "$DOCKER_KEY" >/dev/null

# -----------------------------
# [7/8] Add Docker repo (signed-by)
# -----------------------------
stage 7 "Add Docker APT repo (signed-by keyrings)"

CODENAME="$(. /etc/os-release && echo "${UBUNTU_CODENAME:-${VERSION_CODENAME:-jammy}}")"

echo "deb [arch=$(dpkg --print-architecture) signed-by=${DOCKER_KEY}] ${DOCKER_REPO_BASE} ${CODENAME} stable" \
  | sudo tee "$DOCKER_LIST" >/dev/null

# Remove the disabled file if it exists
sudo rm -f "$DOCKER_LIST_DISABLED" 2>/dev/null || true
sudo rm -rf /var/lib/apt/lists/*

# -----------------------------
# [8/8] Install Docker (dual-stack apt update fallback)
# -----------------------------
stage 8 "Install Docker Engine + Compose plugin (try IPv6 repo fetch, fallback to IPv4)"

# Problem:
# - We want IPv6 for Docker repo if IPv4 is poisoned,
# - but some nodes might not have working IPv6 at the moment.
#
# Solution:
# - Try apt update/install with ForceIPv6=true first
# - If it fails, retry without forcing IPv6 (default path, usually IPv4)

if sudo apt-get -o Acquire::ForceIPv6=true update -y; then
  echo "INFO: Docker repo update succeeded with IPv6 forced"
  sudo apt-get -o Acquire::ForceIPv6=true install -y \
    docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
else
  echo "WARN: Docker repo update failed with IPv6 forced; retrying with default network path (likely IPv4)"
  sudo apt-get update -y
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

# Enable + start docker, and allow vagrant user to run docker without sudo
sudo systemctl enable --now docker
sudo usermod -aG docker vagrant || true

echo "Done."
echo "IMPORTANT: exit and re-SSH for docker group to apply."
echo "Verify:"
echo "  docker version"
echo "  docker run --rm hello-world"