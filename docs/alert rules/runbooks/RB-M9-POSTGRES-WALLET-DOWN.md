# RB-M9-POSTGRES-WALLET-DOWN

Alert
- PostgresWalletDownSymptom

Symptom
- wallet DB failure signal is increasing.

Impact
- wallet-service and upstream services may lose readiness.

First Dashboards
- Dependency and Propagation
- Service Readiness
- Workload and Pod Health

First Checks
- kubectl get pods -n stackpilot-dev | grep postgres-wallet
- kubectl get pods -n stackpilot-dev
- kubectl -n stackpilot-dev port-forward svc/wallet-service 18002:8000
- curl -i http://127.0.0.1:18002/ready
- curl -i http://127.0.0.1:18002/metrics

Likely Causes
- database pod unavailable
- connectivity broken
- bad database release
- storage issue

Recovery
- Restore postgres-wallet
- Wait for wallet-service readiness to recover
- Confirm upstream services recover too

Verification
- wallet_db_check_failures_total stops increasing
- wallet-service readiness returns to 1
- dependent services recover
