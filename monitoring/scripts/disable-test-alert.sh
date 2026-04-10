#!/usr/bin/env bash
set -euo pipefail
kubectl -n monitoring delete prometheusrule stackpilot-phase4-routing --ignore-not-found=true
echo "Deleted test and baseline routing rule set."
echo "Re-apply later with ./monitoring/scripts/install-alert-routing.sh"
