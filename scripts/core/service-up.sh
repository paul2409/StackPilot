#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# scripts/core/service-up.sh
#
# Canonical service startup entrypoint for StackPilot.
#
# Guarantees:
#   1) Services are started ONLY from /vagrant inside the VM
#   2) Compose ALWAYS builds the application image from local source
#   3) Same command works on control/worker1/worker2 via NODE
#   4) Docker daemon DNS is pinned inside the VM (prevents NAT DNS flakes)
#   5) BuildKit is disabled for build stability
#   6) Preflights Docker + container DNS + HTTPS before build
#
# Usage:
#   bash scripts/core/service-up.sh
#   NODE=worker1 bash scripts/core/service-up.sh
#   NODE=worker2 bash scripts/core/service-up.sh
# ==========================================================

# ----------------------------------------------------------
# Resolve repo root safely (works from scripts/core/, scripts/verify/, etc.)
# ----------------------------------------------------------
ROOT_DIR=""
if command -v git >/dev/null 2>&1; then
  ROOT_DIR="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "${ROOT_DIR:-}" ]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
fi

VAGRANT_DIR="${ROOT_DIR}/vagrant"
NODE="${NODE:-control}"

echo "== service-up: starting stack on node '${NODE}' =="

# ----------------------------------------------------------
# Host preflight: ensure Vagrant env exists
# ----------------------------------------------------------
if [ ! -d "${VAGRANT_DIR}" ]; then
  echo "FAIL: vagrant directory not found at: ${VAGRANT_DIR}"
  exit 1
fi
if [ ! -f "${VAGRANT_DIR}/Vagrantfile" ]; then
  echo "FAIL: Vagrantfile not found at: ${VAGRANT_DIR}/Vagrantfile"
  exit 1
fi
if ! command -v vagrant >/dev/null 2>&1; then
  echo "FAIL: vagrant is not installed or not in PATH on host."
  exit 1
fi

cd "$VAGRANT_DIR"

echo "== service-up: ensuring VM '${NODE}' is up =="
vagrant up "$NODE" >/dev/null

# ----------------------------------------------------------
# Execute service startup INSIDE the VM
# ----------------------------------------------------------
vagrant ssh "$NODE" -c "bash -s" <<'EOF'
set -euo pipefail

APP_DIR="/vagrant"
COMPOSE_FILE="infra/docker-compose.yml"

# -----------------------------
# Enforce /vagrant execution
# -----------------------------
cd "$APP_DIR"
echo "== vm: enforce /vagrant execution =="
if [ "$(pwd)" != "/vagrant" ]; then
  echo "FAIL: must run from /vagrant inside the VM"
  echo "Current directory: $(pwd)"
  exit 1
fi
echo "PASS: running from /vagrant"

# -----------------------------
# Require docker + compose
# -----------------------------
echo "== vm: preflight: docker present =="
command -v docker >/dev/null 2>&1 || { echo "FAIL: docker not found in VM"; exit 1; }
echo "Docker: $(docker --version)"

echo "== vm: preflight: docker compose present =="
if docker compose version >/dev/null 2>&1; then
  DC="docker compose"
elif command -v docker-compose >/dev/null 2>&1; then
  DC="docker-compose"
else
  echo "FAIL: docker compose not found (neither 'docker compose' nor 'docker-compose')."
  exit 1
fi
echo "Compose: $DC"

# -----------------------------
# HARD FIX: Pin Docker daemon DNS (idempotent) + restart docker if needed
# -----------------------------
echo "== vm: pin docker daemon DNS (idempotent) =="
DESIRED_MIN='{"dns":["1.1.1.1","8.8.8.8"]}'
CURRENT_MIN=""

if command -v sudo >/dev/null 2>&1; then
  sudo mkdir -p /etc/docker

  if [ -f /etc/docker/daemon.json ]; then
    CURRENT_MIN="$(tr -d ' \n\t' < /etc/docker/daemon.json || true)"
  fi

  if [ "$CURRENT_MIN" != "$DESIRED_MIN" ]; then
    echo '{ "dns": ["1.1.1.1", "8.8.8.8"] }' | sudo tee /etc/docker/daemon.json >/dev/null

    echo "== vm: restarting docker to apply DNS =="
    if command -v systemctl >/dev/null 2>&1; then
      sudo systemctl restart docker
    else
      sudo service docker restart
    fi
    echo "PASS: daemon DNS pinned + docker restarted"
  else
    echo "PASS: daemon DNS already pinned (no restart needed)"
  fi
else
  echo "WARN: sudo not available; cannot pin daemon DNS automatically."
fi

# -----------------------------
# Preflight: container DNS + HTTPS
# -----------------------------
echo "== vm: preflight: container DNS =="
docker run --rm busybox nslookup pypi.org >/dev/null
docker run --rm busybox nslookup files.pythonhosted.org >/dev/null
echo "PASS: container DNS ok"

echo "== vm: preflight: HTTPS reachability =="
docker run --rm curlimages/curl:8.5.0 -I https://pypi.org >/dev/null
echo "PASS: HTTPS ok"

# -----------------------------
# Preflight: compose file exists
# -----------------------------
echo "== vm: preflight: compose file exists =="
[ -f "$COMPOSE_FILE" ] || { echo "FAIL: compose file not found: $COMPOSE_FILE"; exit 1; }
echo "PASS: found $COMPOSE_FILE"

# -----------------------------
# Build + up (stability-first)
# -----------------------------
echo "== vm: compose build (local source; BuildKit disabled; plain progress) =="
DOCKER_BUILDKIT=0 BUILDKIT_PROGRESS=plain $DC -f "$COMPOSE_FILE" build

echo "== vm: compose up =="
$DC -f "$COMPOSE_FILE" up -d

echo "== vm: compose ps =="
$DC -f "$COMPOSE_FILE" ps

echo "== vm: service-up complete =="
EOF

echo "== service-up: done =="