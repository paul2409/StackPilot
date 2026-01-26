#!/usr/bin/env bash
set -euo pipefail

# ==========================================================
# scripts/reviewer-demo.sh
#
# Reviewer-friendly end-to-end proof.
#
# What it proves:
#   1) Clean-room removes containers + removes APP image (infra-api)
#   2) Golden path rebuilds the APP image
#   3) Verification suite passes (host + cluster + verify-build)
#
# What it DOES NOT do:
#   - It does NOT destroy VMs (that is "make destroy")
#
# Usage:
#   bash scripts/reviewer-demo.sh
#   NODE=worker1 bash scripts/reviewer-demo.sh
#
# Optional:
#   APP_IMAGE=infra-api NODE=worker1 bash scripts/reviewer-demo.sh
# ==========================================================

NODE="${NODE:-control}"
APP_IMAGE="${APP_IMAGE:-infra-api}"

echo "=============================================="
echo " StackPilot Reviewer Demo (Milestone 03)"
echo " NODE      : ${NODE}"
echo " APP_IMAGE : ${APP_IMAGE}"
echo "=============================================="
echo ""

echo "== 1) Clean-room teardown (MANDATORY) =="
# Clean-room: removes compose containers + removes APP image + verifies it is gone
NODE="${NODE}" APP_IMAGE="${APP_IMAGE}" make clean
echo ""

echo "== 2) Evidence: confirm APP image is gone BEFORE rebuild =="
# We check inside the VM directly to avoid any host-vs-VM confusion.
cd vagrant
vagrant ssh "${NODE}" -c "docker image ls | grep -E '^${APP_IMAGE}(\s|:)' && exit 1 || echo 'PASS: app image is absent (clean-room proven)'"
cd ..
echo ""

echo "== 3) Start services (golden path) =="
# service-up.sh forces compose build + up (your milestone03 step 3)
NODE="${NODE}" make demo
echo ""

echo "== 4) Evidence: confirm APP image exists AFTER rebuild =="
cd vagrant
vagrant ssh "${NODE}" -c "docker image ls | grep -E '^${APP_IMAGE}(\s|:)' && echo 'PASS: app image rebuilt (golden path proven)' || (echo 'FAIL: app image missing after demo' && exit 1)"
cd ..
echo ""

echo "== 5) Full verification suite =="
NODE="${NODE}" make verify
echo ""

echo "=============================================="
echo " REVIEWER DEMO: PASS"
echo " Clean-room -> rebuild -> verify completed"
echo "=============================================="