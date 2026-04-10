# RB-M9-HIGH-LATENCY

Alert
- StackPilotHighLatencyP95

Symptom
- Request latency p95 is elevated.

Impact
- Users may experience slowness before outright failures.

First Dashboards
- Requests and Errors
- Dependency and Propagation
- Release and Version

First Checks
- Compare latency by service
- Compare latency by handler
- Check dependency dashboards
- Check recent release changes

Likely Causes
- dependency slowdown
- overloaded service
- bad release

Recovery
- Restore healthy dependency
- Or roll back the bad release

Verification
- p95 returns to normal range
