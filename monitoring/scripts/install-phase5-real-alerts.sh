#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f monitoring/alerts/m9-phase5-real-alert-rules.yaml

echo
echo "Applied phase 5 real alert rules."
echo "Next: verify the rules exist and start with one controlled real failure drill."
