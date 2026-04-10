# RB-M9-OPS-PORTAL-NOT-READY

Alert
- OpsPortalNotReady

Symptom
- ops-portal is not ready.

Impact
- Ops and diagnostic surfaces are degraded.

First Dashboards
- Service Readiness
- Dependency and Propagation
- Workload and Pod Health

First Checks
- kubectl get pods -n stackpilot-dev
- kubectl -n stackpilot-dev port-forward svc/ops-portal 18006:8000
- curl -i http://127.0.0.1:18006/ready
- Check wallet-service readiness
- Check system-service readiness
- Check identity-service readiness

Likely Causes
- downstream dependency failure
- bad portal release
- probe mismatch

Recovery
- Restore dependency
- Or roll back ops-portal

Verification
- ops-portal readiness returns to 1
- /ready returns success
