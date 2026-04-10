# RB-M9-RESTART-LOOP

Alert
- StackPilotRestartLoop

Symptom
- Restart count is rising rapidly.

Impact
- One or more workloads may be unstable or unavailable.

First Dashboards
- Workload and Pod Health
- Cluster Health

First Checks
- kubectl get pods -n stackpilot-dev
- kubectl get pods -n argocd
- kubectl describe pod <failing-pod> -n <namespace>
- kubectl logs <failing-pod> -n <namespace> --previous

Likely Causes
- crash loop
- bad config
- failed dependency
- probe mismatch

Recovery
- Fix workload issue
- Restart or redeploy only if needed
- Confirm restarts stop climbing

Verification
- restart increase stops growing abnormally
- workload returns healthy
