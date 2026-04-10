# RB-M9-DEPLOYMENT-UNAVAILABLE

Alert
- StackPilotDeploymentUnavailable

Symptom
- One or more StackPilot deployments have unavailable replicas.

Impact
- Platform capacity or availability is degraded.

First Dashboards
- Workload and Pod Health
- Cluster Health

First Checks
- kubectl get deploy -n stackpilot-dev
- kubectl get pods -n stackpilot-dev
- kubectl describe deploy <deployment> -n stackpilot-dev

Likely Causes
- bad rollout
- failed probes
- crashloop
- scheduling issue

Recovery
- Fix rollout issue
- Confirm desired and available replicas converge

Verification
- unavailable replicas return to 0
