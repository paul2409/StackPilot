#!/usr/bin/env bash
set -euo pipefail

RULE_FILE="monitoring/alerts/m9-phase5-real-alert-rules.yaml"
RUNBOOK_DIR="docs/m9/runbooks"

echo "== check alert rules file exists =="
test -f "${RULE_FILE}"
echo "ok"
echo

echo "== list alerts =="
grep 'alert:' "${RULE_FILE}" || true
echo

echo "== list runbook annotations =="
grep 'runbook:' "${RULE_FILE}" || true
echo

echo "== verify every runbook annotation points to a real file =="
MISSING=0
for path in $(grep 'runbook:' "${RULE_FILE}" | sed 's/.*runbook: "\(.*\)"/\1/' | sort -u); do
  if [ -f "${path}" ]; then
    echo "[OK] ${path}"
  else
    echo "[MISSING] ${path}"
    MISSING=1
  fi
done
echo

echo "== verify key runbook sections =="
for file in ${RUNBOOK_DIR}/*.md; do
  echo "-- ${file}"
  grep -q '^Symptom' "${file}" && echo "  symptom: ok" || echo "  symptom: missing"
  grep -q '^Impact' "${file}" && echo "  impact: ok" || echo "  impact: missing"
  grep -q '^First Checks' "${file}" && echo "  first checks: ok" || echo "  first checks: missing"
  grep -q '^Likely Causes' "${file}" && echo "  likely causes: ok" || echo "  likely causes: missing"
  grep -q '^Recovery' "${file}" && echo "  recovery: ok" || echo "  recovery: missing"
  grep -q '^Verification' "${file}" && echo "  verification: ok" || echo "  verification: missing"
done
echo

if [ "${MISSING}" -ne 0 ]; then
  echo "Runbook linkage verification failed."
  exit 1
fi

echo "Phase 6 runbook linkage verification passed."
