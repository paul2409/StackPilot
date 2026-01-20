#!/usr/bin/env bash
set -e

echo "[up] Building mock-exchange image..."
docker build -t stackpilot/mock-exchange:0.2.0 /vagrant/apps/mock-exchange

echo "[up] Starting mock-exchange container..."
docker run -d --name mock-exchange \
  -p 8000:8000 \
  -e SERVICE_NAME=mock-exchange \
  -e ENV=dev \
  -e LOG_LEVEL=info \
  -e VERSION=0.2.0 \
  -e BUILD_TIME=local \
  -e GIT_SHA=local \
  stackpilot/mock-exchange:0.2.0

echo "[up] Done. Test: curl http://127.0.0.1:8000/health"
