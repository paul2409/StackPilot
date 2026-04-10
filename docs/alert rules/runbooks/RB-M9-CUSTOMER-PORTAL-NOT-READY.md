# RB-M9-CUSTOMER-PORTAL-NOT-READY

Alert
- CustomerPortalNotReady

Symptom
- customer-portal is not ready.

Impact
- Customer-facing flows may be degraded.

First Dashboards
- Service Readiness
- Dependency and Propagation
- Workload and Pod Health

First Checks
- kubectl get pods -n stackpilot-dev
- kubectl -n stackpilot-dev port-forward svc/customer-portal 18004:8000
- curl -i http://127.0.0.1:18004/ready
- Check wallet-service readiness
- Check identity-service readiness

Likely Causes
- downstream dependency failure
- bad portal release
- probe mismatch

Recovery
- Restore dependency
- Or roll back customer-portal

Verification
- customer-portal readiness returns to 1
- /ready returns success
