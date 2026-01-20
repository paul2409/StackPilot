#!/usr/bin/env bash
set -e

echo "[down] Stopping mock-exchange (if running)..."
docker stop mock-exchange 2>/dev/null || true

echo "[down] Removing mock-exchange container (if exists)..."
docker rm mock-exchange 2>/dev/null || true

echo "[down] Done."
