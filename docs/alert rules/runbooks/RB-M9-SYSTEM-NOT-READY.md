# RB-M9-SYSTEM-NOT-READY

Alert
- SystemServiceNotReady

Symptom
- system-service is not ready.

Impact
- Summary and diagnostic surfaces may be degraded.

First Dashboards
- Service Readiness
- Dependency and Propagation

First Checks
- kubectl get pods -n stackpilot-dev
- kubectl -n stackpilot-dev port-forward svc/system-service 18007:8000
- curl -i http://127.0.0.1:18007/ready
- Check wallet-service and identity-service readiness

Likely Causes
- downstream dependency failure
- bad release
- probe mismatch

Recovery
- Restore the failing dependency
- Or roll back system-service

Verification
- system-service readiness returns to 1
- /ready returns success
