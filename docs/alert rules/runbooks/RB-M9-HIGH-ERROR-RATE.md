# RB-M9-HIGH-ERROR-RATE

Alert
- StackPilotHighErrorRate

Symptom
- 5xx error rate is elevated.

Impact
- Users may be seeing visible failures.

First Dashboards
- Requests and Errors
- Dependency and Propagation
- Release and Version

First Checks
- Identify failing service
- Identify failing handler
- Check whether a dependency is broken
- Check recent rollout/version change

Likely Causes
- dependency issue
- bad release
- ingress/app error path

Recovery
- Fix failing service or dependency
- Roll back if the release caused the issue

Verification
- 5xx rate falls back to baseline
