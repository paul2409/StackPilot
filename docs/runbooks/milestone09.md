Milestone09: End-to-End Observability + Alerting + Incident Demo

Purpose

The platform is now operable, not just deployable. This milestone makes system behavior measurable, diagnosable, and recoverable through integrated observability and alerting.

⸻

System Overview

Three observability layers:

1. Metrics Layer — provides readiness, errors, latency, dependency failures, pod health, and cluster state
2. Dashboard Layer — Grafana turns raw metrics into operational views answering readiness, workload, dependency, and traffic questions
3. Alerting Layer — Alertmanager routes meaningful failures to Discord with runbook guidance

Observed System:
•	Services: identity-service, wallet-service, system-service, customer-portal, admin-portal, ops-portal
•	Dependencies: postgres-identity, postgres-wallet
•	Platform: ingress-nginx, Argo CD, Prometheus, Grafana, Alertmanager, Discord bridge

⸻

What Must Be Observable

By Milestone 09 completion:
•	which service is alive and ready
•	which workload is degraded
•	which dependency is broken
•	whether wallet failure propagates upstream
•	whether requests are failing and latency is rising
•	whether a rollout changed behavior
•	whether recovery actually happened

⸻

Metrics Foundation

Prometheus scrapes application /metrics endpoints, kube-state-metrics, node metrics, and ingress metrics.

Key application metrics:
•	service_ready_state
•	service_build_info
•	http_requests_total, http_request_duration_seconds
•	dependency_check_failures_total
•	wallet_db_check_failures_total, identity_db_check_failures_total
•	customer_portal_upstream_failures_total, admin_portal_upstream_failures_total
•	ops_dependency_unready_total, system_dependency_unready_total
•	wallet_dependency_state

Verification checklist:
•	Prometheus targets are up
•	Per-service readiness is visible
•	DB failure counters move when dependencies break
•	Upstream degradation is measurable
•	Request and latency signals exist

⸻

Dashboard Set

Six Grafana dashboards answer operator questions:

1. Service Readiness: Which services are ready? Is wallet the first failure anchor?
2. Workload and Pod Health: Which deployment is degraded? Are workloads under-replicated or crashlooping?
3. Dependency and Propagation: If wallet breaks, who degrades next? Where are dependency failures accumulating?
4. Requests and Errors: Are requests flowing? Which services are erroring? Is latency rising?
5. Cluster/Workload Health: Distinguish app failure, workload failure, and platform instability
6. Release/Version: What version is deployed? Did behavior change after rollout?

⸻

Alert Routing Model

Alert taxonomy:

Critical: dependency failure causing major readiness loss, wallet-service not ready, DB down symptom, multi-service degradation

Warning: single service not ready, restart loops, deployment unavailable, elevated error rate, high latency

Info: test routing, resolved notifications, recovery events

Required metadata on every serious alert:
alert name, severity, owner, summary, impact, first_check, likely_cause, recovery, runbook, runbook_id

⸻

Alert Delivery

Working path: Prometheus → Alertmanager → Discord bridge → Discord channel

Components:
•	Discord webhook secret
•	Bridge deployment + service
•	Alertmanager root/global routing fix
•	Routed delivery by severity
•	Firing and resolved notifications

Discord channel is the local operator notification surface.

⸻

Real Alert Rules

Readiness: WalletServiceNotReady, SystemServiceNotReady, CustomerPortalNotReady, AdminPortalNotReady, OpsPortalNotReady

Dependency Symptoms: PostgresWalletDownSymptom, PostgresIdentityDownSymptom, WalletDependencyPropagation

Stability: StackPilotRestartLoop, StackPilotDeploymentUnavailable

Traffic/Error: StackPilotHighErrorRate, StackPilotHighLatencyP95

Design principle: alert on operationally meaningful failure, not generic noise.

⸻

Runbook Linkage

Each serious alert has a response path containing:
•	Symptom and Impact
•	First Dashboards and Checks
•	Likely Causes
•	Recovery steps
•	Verification procedures

Supporting artifacts:
•	alert-to-runbook map
•	runbook linkage verification script
•	alert metadata verification

⸻

Primary Incident Drill: postgres-wallet Outage

Flow:
1. Break postgres-wallet
2. Observe wallet-service /ready fail
3. Observe upstream services degrade
4. Confirm Discord alerts fire
5. Confirm Grafana dashboards show blast radius
6. Recover postgres-wallet
7. Confirm readiness chain recovery
8. Confirm resolved alerts arrive
9. Document incident

Drill proves: dependency truth is real, alerting is actionable, propagation is visible, recovery is measurable, documentation closes the loop.

⸻

Key Failure/Recovery Behavior

Failure handling:
•	DB outage causes wallet readiness loss
•	Upstream services reflect dependency truth
•	Real alerts fire
•	Discord receives firing notifications
•	Grafana shows degradation

Recovery handling:
•	DB restored
•	Wallet readiness returns
•	Upstream services recover
•	Resolved alerts appear
•	Dashboards return healthy

⸻

Completion Criteria

Milestone 09 is complete when:
•	Prometheus scrapes real application and platform metrics
•	Grafana dashboards answer operator questions
•	Alertmanager routes real alerts correctly
•	Discord receives firing and resolved alerts
•	Every serious alert has severity, owner, and runbook linkage
•	At least one full real incident drill is completed successfully
•	The system is recovered and incident is documented
•	A reviewer can follow the proof flow end to end

⸻

Demo Flow

1. Show Healthy State: Open Grafana dashboards and Discord channel, confirm all services healthy

2. Show Alerting Exists: Verify PrometheusRule definitions, Alertmanager, Discord bridge, and runbooks exist

3. Inject Failure: Break postgres-wallet, confirm postgres-wallet unavailable and wallet-service /ready fails

4. Observe Alerting: Check Discord for PostgresWalletDownSymptom, WalletServiceNotReady, and portal readiness alerts

5. Observe Diagnosis: Verify in Grafana that readiness drops, upstream degrades, dependency counters rise, workload disruption visible

6. Recover: Restore postgres-wallet, verify it returns and services recover

7. Confirm Recovery Signals: Check resolved Discord alerts and Grafana healthy state restored

8. Show Incident Record: Present timeline, root cause, affected services, detection path, dashboards used, recovery action, verification, and lessons learned

⸻

What This Proves

•	StackPilot is measurable
•	StackPilot is diagnosable
•	StackPilot can notify an operator
•	StackPilot can recover from real dependency failure
•	StackPilot can document incident response
•	StackPilot is operable, not just deployable

⸻

End State

•	Metrics exist and matter
•	Dashboards answer real questions
•	Alerts are actionable
•	Discord routing works
•	Runbooks are linked
•	Incident drills are repeatable
•	Recovery is verifiable
•	M9 is closed