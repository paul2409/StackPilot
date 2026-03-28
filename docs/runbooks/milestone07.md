Milestone 07 — Kubernetes Runtime Authority + Helm Release Discipline

Purpose

Milestone 07 establishes Kubernetes as the runtime authority for StackPilot and Helm as the release authority for the six-service platform.

At this stage, the platform is no longer defined by Docker Compose assumptions or human judgment.

Kubernetes owns:
	•	workload scheduling
	•	service discovery
	•	readiness enforcement
	•	rollout safety
	•	traffic eligibility

Helm owns:
	•	release packaging
	•	release installation
	•	release upgrade
	•	release rollback
	•	environment value separation

This milestone proves that the platform runs as a real controlled system, not just as a collection of containers. That matches the intended role of M7 and M7.5 in your six-service continuation plan: Kubernetes enforces runtime guarantees, then Helm turns the stack into a releasable system.  ￼

⸻

Scope (What This Milestone Covers)
	•	full six-service deployment to local k3s
	•	in-cluster Postgres for identity and wallet
	•	Kubernetes Deployments and Services for all workloads
	•	NGINX ingress routing for customer/admin/ops
	•	honest /health, /ready, /version contracts
	•	dependency propagation across services
	•	stable rollout verification
	•	bad release drills
	•	Helm chart for full stack
	•	Helm install / upgrade / rollback proof
	•	values-based environment separation for local use

⸻

Non-Goals (Explicitly Out of Scope)
	•	Argo CD or GitOps authority
	•	EKS or AWS deployment
	•	Prometheus / Grafana / Alertmanager
	•	autoscaling or load testing
	•	production-grade secret management
	•	multi-environment cloud deployment
	•	long-lived cloud infrastructure

These are intentionally deferred to M8 and beyond. Your milestone sequence already places Argo CD in M8 and AWS in M9.  ￼

⸻

Runtime Authority Model

Kubernetes becomes the runtime truth engine.

Runtime now consists of one authoritative control plane:
	•	k3s controllers determine what runs
	•	Services determine what is reachable
	•	readiness determines what is allowed to receive traffic

Helm becomes the release control layer:
	•	chart defines deployable shape
	•	values define environment-specific overrides
	•	revision history defines rollback points

Delivery is no longer:
	•	manual container execution
	•	Compose startup order luck
	•	“it seems up”

Delivery is now:
	•	declarative
	•	probe-driven
	•	revisioned
	•	recoverable

⸻

Workload Structure

The authoritative M7 runtime includes:

Databases:
	•	postgres-identity
	•	postgres-wallet

Core services:
	•	identity-service
	•	wallet-service
	•	system-service

Portal layer:
	•	customer-portal
	•	admin-portal
	•	ops-portal

Ingress:
	•	NGINX ingress
	•	customer.local
	•	admin.local
	•	ops.local

Every service must expose:
	•	/health
	•	/ready
	•	/version

That is a locked M7 requirement, and the six-service continuation plan explicitly fixes these service contracts before deeper GitOps work begins.  ￼

⸻

Kubernetes Runtime Authority Model

Kubernetes becomes the authoritative state machine for local platform runtime.

Runtime consists of:
	1.	manifest-defined desired state
	2.	controller reconciliation
	3.	readiness truth enforcement
	4.	service-based routing
	5.	ingress-based entry
	6.	rollout acceptance or rejection

The local cluster is no longer judged by:
	•	pods existing
	•	images pulling
	•	containers starting

The cluster is judged by:
	•	services becoming ready
	•	dependencies resolving correctly
	•	ingress reaching usable workloads
	•	bad releases being blocked by readiness

⸻

Phase Structure

Stage 1 — Contract Freeze

The six-service system must stop changing shape arbitrarily.

Locked interfaces:

Identity:
	•	/login
	•	/me
	•	/users

Wallet:
	•	/balances
	•	/history
	•	/transfer

System:
	•	/status

Customer portal:
	•	/api/auth/login
	•	/api/auth/me
	•	/api/wallet/balances
	•	/api/wallet/history
	•	/api/profile

Admin portal:
	•	/api/admin/system-summary
	•	/api/admin/users
	•	/api/admin/wallets

Ops portal:
	•	/ops/dependencies
	•	/ops/diagnostics

No random route expansion.

Reason:
GitOps later depends on runtime contracts being stable enough to reconcile meaningfully.  ￼

⸻

Stage 2 — Kubernetes Migration

All six services and both databases must run in k3s.

Required Kubernetes components:
	•	namespace
	•	Deployment per workload
	•	Service per workload
	•	ingress resource
	•	environment wiring
	•	labels/selectors
	•	liveness probe
	•	readiness probe

This stage is not complete when manifests apply.

It is complete when:
	•	all workloads run
	•	services resolve by DNS
	•	portals can reach their dependencies
	•	ingress routes externally
	•	database-backed services function in-cluster

That is the actual M7 exit path: all six services and both Postgres dependencies run in k3s.  ￼

⸻

Stage 3 — Honest Probes Become Law

This is the most important runtime rule in M7.

Probe semantics:

/health
	•	process alive only

/ready
	•	dependency truth

Examples:
	•	if postgres-wallet dies, wallet-service may still be alive, so /health stays OK but /ready fails
	•	if wallet-service is not ready, dependent portals must reflect that through their own readiness logic
	•	ingress and Services must route only to ready workloads

This is the core runtime truth principle of M7.  ￼

⸻

Stage 4 — Stable Rollout Behavior

Kubernetes must prove that it blocks bad runtime truth, not just launches pods.

Required drills:
	•	deploy good image and verify stable rollout
	•	deploy broken image and observe readiness failure
	•	confirm bad pods do not become traffic truth
	•	confirm traffic only reaches ready workloads

Best drills for your stack:
	•	bad wallet-service image
	•	bad customer-portal image
	•	broken readiness path

This is explicitly part of the M7 rollout-safety intent in your milestone plan.  ￼

⸻

Stage 5 — Helm Release Packaging

Once raw runtime truth works, Helm becomes the release layer.

Helm now owns:
	•	chart structure
	•	templated images
	•	tags
	•	replica counts
	•	env vars
	•	ports
	•	probes
	•	ingress hosts
	•	environment value separation

Helm must prove:
	•	install works
	•	upgrade works
	•	bad values can break a release
	•	rollback restores service

That is the exact purpose of M7.5.5 in your continuation plan.  ￼

⸻

Verification Standard

Verification is not superficial.

M7 verification must prove:
	•	all Deployments available
	•	all Services reachable
	•	ingress working
	•	/health, /ready, /version across all services
	•	dependency-aware behavior is honest
	•	rollout failure is observable
	•	release rollback restores correctness

This aligns with the required make k8s-verify behavior defined for M7.  ￼

⸻

Makefile / Operator Authority

Runtime lifecycle is not controlled through random commands.

M7 authority should be expressed through stable commands such as:
	•	make k8s-up
	•	make k8s-status
	•	make k8s-verify
	•	make k8s-drill-wallet-db
	•	make k8s-drill-wallet-bad-release
	•	make k8s-down

Helm lifecycle should be understood through:
	•	helm install
	•	helm upgrade
	•	helm history
	•	helm rollback
	•	helm uninstall

If it is not part of the stable operator path, it should not be treated as normal delivery behavior.

⸻

Failure Handling

Failures are intentional, visible, and blocking.

M7 requires:
	•	readiness failures block truth
	•	broken images surface clearly
	•	dependency loss propagates upstream
	•	rollout failure is observable
	•	rollback restores known-good state
	•	no silent success

The platform must either:
	•	run truthfully
	•	fail truthfully

Nothing in between.

⸻

Helm Discipline

Helm is not just “templated YAML.”

For this milestone, Helm must establish:
	•	release identity
	•	revision history
	•	upgrade path
	•	rollback path
	•	values-based control
	•	environment file layering

Minimum useful environment structure:
	•	values.yaml
	•	values-dev.yaml
	•	values-staging.yaml

This prepares the platform for GitOps in M8 without overcomplicating local work. The continuation plan explicitly recommends this values layering before Argo CD.  ￼

⸻

Cleanup / State Discipline

M7 is local, so “cleanup” means cluster state discipline rather than AWS resource deletion.

Cleanup proof means:
	•	helm uninstall removes Helm-owned release resources
	•	make k8s-down removes stack resources cleanly
	•	old broken pods do not linger as deployment authority
	•	reinstall from chart works cleanly
	•	cluster can return to a known baseline

This is the local equivalent of deterministic lifecycle discipline.

⸻

End State Guarantees

After Milestone 07:
	•	Kubernetes is authoritative for runtime truth
	•	Helm is authoritative for release packaging
	•	all six services run in k3s
	•	ingress works
	•	readiness is honest
	•	bad deployments are visibly blocked by readiness
	•	dependency failures propagate correctly
	•	verification is repeatable
	•	releases can be installed, upgraded, and rolled back cleanly

That is the actual locked M7 completion state for your six-service system.  ￼

⸻

Milestone 07 intentionally stops after proving that:

The six-service platform can run as a controlled Kubernetes system, and Helm can manage it as a releasable stack.

The system is no longer “containers that happen to start.”

It now behaves like a platform runtime with release discipline.

⸻
