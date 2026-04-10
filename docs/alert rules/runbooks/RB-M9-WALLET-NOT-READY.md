# RB-M9-WALLET-NOT-READY

Alert
- WalletServiceNotReady

Symptom
- wallet-service is not ready.

Impact
- Wallet-backed flows may fail.
- Upstream services may become not ready.

First Dashboards
- Service Readiness
- Dependency and Propagation
- Workload and Pod Health

First Checks
- kubectl get pods -n stackpilot-dev
- kubectl -n stackpilot-dev port-forward svc/wallet-service 18002:8000
- curl -i http://127.0.0.1:18002/ready
- curl -i http://127.0.0.1:18002/health
- Check postgres-wallet pod state

Likely Causes
- postgres-wallet unavailable
- bad wallet-service release
- bad config
- probe mismatch

Recovery
- Restore postgres-wallet
- Or roll back wallet-service
- Confirm wallet-service becomes ready again

Verification
- service_ready_state for wallet-service returns to 1
- wallet /ready returns success
- upstream services recover if they degraded
