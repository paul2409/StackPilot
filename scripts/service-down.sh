#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAGRANT_DIR="${ROOT_DIR}/vagrant"

APP_DIR="/vagrant"
COMPOSE_FILE="infra/docker-compose.yml"

echo "== service-down: stopping stack on control =="

cd "$VAGRANT_DIR"
vagrant ssh control -c "cd ${APP_DIR} && docker compose -f ${COMPOSE_FILE} down"

echo "== service-down: done =="
