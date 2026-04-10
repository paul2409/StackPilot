# RB-M9-WALLET-PROPAGATION

Alert
- WalletDependencyPropagation

Symptom
- wallet failure is propagating into upstream services.

Impact
- customer/admin/ops/system surfaces may be degraded because wallet is not ready.

First Dashboards
- Dependency and Propagation
- Service Readiness

First Checks
- Confirm wallet-service failed first
- Check which upstream services are not ready
- Check postgres-wallet status

Likely Causes
- postgres-wallet failure
- wallet-service bad release
- wallet dependency truth working as designed

Recovery
- Restore wallet root cause
- Then confirm upstream services recover

Verification
- wallet-service readiness returns to 1
- upstream services return to 1
