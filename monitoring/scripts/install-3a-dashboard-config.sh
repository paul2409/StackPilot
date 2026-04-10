#!/usr/bin/env bash
set -euo pipefail

MON_NS="${MON_NS:-monitoring}"

kubectl -n "${MON_NS}" create configmap grafana-dashboard-m9-3a \
  --from-file=monitoring/grafana/dashboards/m9-3a-service-readiness.dashboard.json \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "${MON_NS}" create configmap grafana-dashboard-provider-stackpilot-m9 \
  --from-file=monitoring/grafana/provisioning/dashboards/stackpilot-m9-dashboards.yaml \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "${MON_NS}" create configmap grafana-datasource-prometheus \
  --from-file=monitoring/grafana/provisioning/datasources/prometheus.yaml \
  --dry-run=client -o yaml | kubectl apply -f -

echo "ConfigMaps created."
echo "Next: mount them into Grafana if you want file-based provisioning, or import the dashboard JSON manually in Grafana."
