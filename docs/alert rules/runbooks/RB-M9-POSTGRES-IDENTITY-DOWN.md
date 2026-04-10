# RB-M9-POSTGRES-IDENTITY-DOWN

Alert
- PostgresIdentityDownSymptom

Symptom
- identity DB failure signal is increasing.

Impact
- identity-service and upstream services may lose readiness.

First Dashboards
- Dependency and Propagation
- Service Readiness
- Workload and Pod Health

First Checks
- kubectl get pods -n stackpilot-dev | grep postgres-identity
- kubectl get pods -n stackpilot-dev
- Check identity-service /ready
- Check dependent services

Likely Causes
- database pod unavailable
- connectivity broken
- bad database release
- storage issue

Recovery
- Restore postgres-identity
- Wait for identity-service readiness to recover

Verification
- identity_db_check_failures_total stops increasing
- identity-service readiness returns to 1
