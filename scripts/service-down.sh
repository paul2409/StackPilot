#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAGRANT_DIR="${ROOT_DIR}/vagrant"

# Default node remains control unless NODE is provided
NODE="${NODE:-control}"

APP_DIR="/vagrant"
COMPOSE_FILE="infra/docker-compose.yml"

echo "== service-down: stopping stack on ${NODE} =="

cd "$VAGRANT_DIR"
vagrant ssh "$NODE" -c "cd ${APP_DIR} && docker compose -f ${COMPOSE_FILE} down"

echo "== service-down: done =="
