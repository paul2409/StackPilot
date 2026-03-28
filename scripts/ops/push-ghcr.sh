#!/usr/bin/env bash
set -euo pipefail

GITHUB_USER="paul2409"
TAG="${1:-dev}"

# FIXED ROOT PATH
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

build_and_push() {
  local image_name="$1"
  local context_dir="$2"

  echo "=================================================="
  echo "Building ${image_name}:${TAG}"
  echo "Context: ${context_dir}"
  echo "=================================================="

  docker build \
    -t "ghcr.io/${GITHUB_USER}/${image_name}:${TAG}" \
    "${ROOT_DIR}/${context_dir}"

  echo "Pushing ghcr.io/${GITHUB_USER}/${image_name}:${TAG}"
  docker push "ghcr.io/${GITHUB_USER}/${image_name}:${TAG}"
}

# services
build_and_push "identity-service" "services/identity-service"
build_and_push "wallet-service" "services/wallet-service"
build_and_push "system-service" "services/system-service"

# portals
build_and_push "customer-portal" "apps/stackpilot-exchange/customer-portal"
build_and_push "admin-portal" "apps/stackpilot-exchange/admin-portal"
build_and_push "ops-portal" "apps/stackpilot-exchange/ops-portal"

echo
echo "All images built and pushed successfully."
echo "Tag used: ${TAG}"