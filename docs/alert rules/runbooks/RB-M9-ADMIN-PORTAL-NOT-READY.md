# RB-M9-ADMIN-PORTAL-NOT-READY

Alert
- AdminPortalNotReady

Symptom
- admin-portal is not ready.

Impact
- Admin operational visibility is degraded.

First Dashboards
- Service Readiness
- Dependency and Propagation
- Workload and Pod Health

First Checks
- kubectl get pods -n stackpilot-dev
- kubectl -n stackpilot-dev port-forward svc/admin-portal 18005:8000
- curl -i http://127.0.0.1:18005/ready
- Check wallet-service readiness
- Check system-service readiness
- Check identity-service readiness

Likely Causes
- downstream dependency failure
- bad portal release
- probe mismatch

Recovery
- Restore dependency
- Or roll back admin-portal

Verification
- admin-portal readiness returns to 1
- /ready returns success
