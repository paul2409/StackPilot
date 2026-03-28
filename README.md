## StackPilot — Platform Engineering Lab

Standard Deploys, Happy Developers

StackPilot is a local-first Platform Engineering and SRE lab.
It is operated as a system with explicit guarantees, executable verification, and recovery paths — not as a tutorial, demo, or sandbox.

The repository is built incrementally through milestones.
Each milestone is merged only when its guarantees are provable through executable verification, not manual inspection.

⸻

# Lab Topology (Host-only Network)

control   — 192.168.56.10
worker1   — 192.168.56.11
worker2   — 192.168.56.12

All nodes run Ubuntu 22.04 LTS with static hostnames and IPs.
The host-only network allows all guarantees to be verified externally from the host.

⸻

# Golden Commands (Canonical)

These are the only supported ways to operate the lab.

All operational scripts enforce execution inside the VM from /vagrant.
If the repository is not mounted at /vagrant, execution fails fast.

Canonical service lifecycle

make up
make demo
make verify
make down

Clean-room / reviewer flows

make clean
make demo-reviewer
make destroy

If make verify does not PASS, the system is not considered working.

Manual SSH success, ad-hoc Docker commands, or partial service health do not override verification failure.

⸻

# Repository Structure

.github/         — GitHub automation
  workflows/     — CI workflows (Actions)

apps/            — sample services used to prove platform behavior
  mock-exchange/ — mock exchange API service (Dockerized)

ci/              — CI artifacts + local CI-facing outputs
  logs/          — CI log files (checks.log / verify.log via workflow tee)

docs/            — guarantees, runbooks, and recovery docs
  runbooks/      — milestone runbooks + troubleshooting workflow

infra/           — infrastructure and delivery definitions
  docker-compose.yml  — canonical service runtime definition
  terraform/     — Terraform structure authority (introduced in Milestone 04+)

scripts/         — lifecycle, clean-room, checks, and verification logic
  access/        — SSH / access helpers for nodes
  checks/        — repo-level contracts (policy/secrets/guarantees/build/etc.)
  core/          — golden-path lifecycle (service up/down, clean-room)
  drills/        — controlled failure injection + recovery proofs
  ops/           — operational helpers (logs, diagnostics)
  provision/     — provisioning/bootstrap logic for lab setup
  verify/        — verification suite (host/cluster/build truth)

tmp/             — scratch workspace (non-authoritative, safe to delete)

vagrant/         — VM definitions, networking, and node identity

Scripts are organized by responsibility:
	•	lifecycle scripts mutate state
	•	verification scripts assert correctness only
	•	clean-room scripts remove all implicit state

Verification scripts never modify the system.
Lifecycle scripts never assert correctness.

⸻

## Milestone 01 — Lab Foundation (v0.1)

# Goal

Establish a deterministic, reproducible 3-VM lab that all later StackPilot milestones depend on.

What This Milestone Demonstrates
	•	Reproducible environments built from zero
	•	Stable node identity (hostnames and IPs do not drift)
	•	Host → VM connectivity verified externally
	•	VM ↔ VM connectivity verified by hostname (not IP)
	•	Idempotent provisioning safe to re-run
	•	Verification-defined correctness (not manual checks)
	•	Executable runbooks and a controlled failure drill

What “Working” Means

“Working” is defined only by:

make verify

If verification fails, the lab is not considered operational.

# Runbooks
	•	docs/runbooks/milestone01.md
	•	docs/runbooks/troubleshooting.md

# Tag

v0.1 — Lab Foundation (Infrastructure Truth)

⸻

## Milestone 02 — Dockerized Service Contracts & Host-Driven Operations (v0.2)

# Goal

Prove that the lab can run a production-behaving service with explicit lifecycle control, truthful health semantics, and predictable failure behavior — all operated from the host.

What This Milestone Demonstrates
	•	Docker as the enforced runtime (no local execution assumptions)
	•	A real API service with strict startup and runtime contracts
	•	Separation of liveness (/health) and readiness (/ready)
	•	A real external dependency (Postgres)
	•	Failure-first behavior that degrades safely instead of crashing
	•	Explicit TCP-level verification before HTTP checks
	•	Host-driven lifecycle control via Makefile
	•	Portable execution across multiple VMs without code changes
	•	Runnable failure drills with documented recovery

What “Working” Means

The system is considered working only if all of the following are true:
	•	make verify passes from the host
	•	TCP connectivity to the service port is proven
	•	/health reports process liveness only
	•	/ready reflects dependency availability truthfully
	•	Dependency loss causes readiness failure, not crash loops
	•	Data persists across service restarts
	•	The service can run on more than one VM

# Runbooks
	•	docs/runbooks/milestone02.md
	•	docs/runbooks/troubleshooting.md

# Tag

v0.2 — Dockerized Service Contracts & Host-Driven Operations

⸻

## Milestone 03 — Operational Hardening & Delivery Discipline (v0.3)

# Goal

Enforce a single, deterministic operational path for building, running, and verifying services.

This milestone removes ambiguity from delivery by making clean-room rebuilds mandatory and by refusing to operate on stale or implicit state.

What This Milestone Demonstrates
	•	A single supported operator interface (Makefile)
	•	Refusal to run outside the expected execution context
	•	Clean separation between:
	•	stopping services
	•	removing runtime state
	•	destroying infrastructure
	•	Mandatory clean-room rebuilds before verification
	•	Deterministic behavior across multiple VMs
	•	Verification that inspects actual runtime and build state
	•	A reviewer-grade demo flow that cannot bypass rebuild guarantees

What “Working” Means

The system is considered working only if all of the following are true:
	•	make clean removes:
	•	all compose-managed containers
	•	all locally built application images
	•	make demo forces a rebuild through the golden path
	•	make verify passes after a clean-room rebuild
	•	Verification confirms:
	•	the service is running
	•	the expected image is used
	•	the image was rebuilt, not reused
	•	Scripts refuse to run when the repo is not mounted at /vagrant
	•	No manual Docker or SSH intervention is required
	•	The same guarantees hold on more than one VM

# Reviewer Demo Contract

A reviewer can run:

make demo-reviewer

(or NODE=worker1 make demo-reviewer)

This command always performs:
	1.	A clean-room teardown
	2.	A forced rebuild via the golden path
	3.	A full verification pass

If this command passes, the system is considered reproducible and operationally correct.

# Runbooks
	•	docs/runbooks/milestone03.md
	•	docs/runbooks/troubleshooting.md

# Tag

v0.3 — Operational Hardening & Delivery Discipline

⸻

## Milestone 04 — CI Authority & Enforced Contracts (v0.4)

# Goal

Shift enforcement of system guarantees from the human operator to automated CI.

This milestone proves that correctness is enforced before merge, not assumed after.

What This Milestone Demonstrates
	•	CI as a required gate for all changes
	•	A single CI workflow governing all validation paths
	•	CI invoking only Makefile targets (no inline logic)
	•	Clear separation between:
	•	repo-level verification
	•	runtime verification
	•	Capability-aware CI behavior (no false claims of verification)
	•	Deterministic cleanup even when CI fails
	•	Inspectable CI logs for every run

What “Working” Means

The system is considered working only if all of the following are true:
	•	A pull request automatically triggers CI
	•	CI blocks merge when any enforced contract fails
	•	CI runs repo-level checks on hosted runners
	•	CI runs full runtime verification only when VM capability exists
	•	CI never attempts to boot infrastructure when capability is absent
	•	CI artifacts clearly show:
	•	which checks ran
	•	which checks were skipped
	•	why any failure occurred
	•	CI teardown executes even when verification fails

# Runbooks
	•	docs/runbooks/milestone04.md
	•	docs/runbooks/troubleshooting.md

# Tag

v0.4 — CI Authority & Enforced Contracts

⸻

# Guarantees Map

See docs/guarantees-map.txt for a complete list of enforced guarantees and their verification status.

⸻

# Project Philosophy

StackPilot prioritizes operational correctness over feature scope.

The applications are intentionally simple.
The value of the project lies in guarantees, verification, failure behavior, rebuildability, and recovery — not in application complexity.

⸻


## Milestone 05 — AWS Host Deployment & Explicit Cloud Verification (v0.5)

# Goal

Extend StackPilot beyond the local lab and prove that the same guarantees hold on real cloud infrastructure.

This milestone introduces AWS-backed infrastructure managed exclusively through Terraform and verified through explicit, artifact-driven scripts.

Cloud success is not defined by “instance running.”
It is defined by executable verification.

⸻

# What This Milestone Demonstrates

• Terraform-managed AWS infrastructure (no console edits)
• Explicit AWS identity validation before execution
• Operator IP-restricted security groups (no 0.0.0.0/0 exposure)
• Deterministic EC2 convergence via bootstrap
• Deployment of the Dockerized service onto a real EC2 host
• Cloud verification driven only by artifacts (target.env)
• Separation between local verify and cloud verify
• Cloud readiness semantics identical to local semantics
• Proven data persistence across container restart in cloud
• Terraform destroy leaves no tagged residue
• Apply → Verify → Destroy cycle is repeatable

⸻

# What “Working” Means

The system is considered working only if all of the following are true:

• make aws-sts validates AWS identity before any Terraform operation
• make aws-run provisions infrastructure without manual console steps
• artifacts/aws/target.env is generated and used as the single source of cloud truth
• make verify-aws passes without manual exports
• /health and /ready behave identically to local lab semantics
• Data persists across container restarts in cloud
• make aws-destroy removes all EC2 instances and tagged volumes
• No AWS console modifications are required
• Re-running apply after destroy behaves deterministically

If any manual console intervention is required, the milestone is not complete.

⸻

# Runbooks

• docs/runbooks/milestone05.md
• docs/runbooks/troubleshooting.md

⸻

# Tag

v0.5 — AWS Host Deployment & Explicit Cloud Verification

⸻

## Milestone 06 — CI Delivery Authority & Deterministic Lifecycle (v0.6)

# Goal

Transfer infrastructure lifecycle authority from the human operator to CI.

This milestone proves that provisioning, deployment, verification, and destruction can execute deterministically without human involvement.

CI becomes the delivery authority.

⸻

# What This Milestone Demonstrates

• CI-driven Terraform apply
• CI-driven remote deployment
• CI-driven runtime verification
• Unconditional destroy execution (even on failure)
• Cleanup verification after destroy
• Manual-only trigger policy for budget control
• Concurrency lock (one delivery at a time)
• Timeout enforcement to prevent budget burn
• Artifact-driven cloud targeting inside CI
• No interactive prompts during delivery
• Makefile remains the single execution interface

⸻

# What “Working” Means

The system is considered working only if all of the following are true:

• The delivery workflow can be triggered manually in GitHub
• Validation runs before any infrastructure provisioning
• Infrastructure provisions successfully
• Deployment completes successfully
• Verification passes against the live endpoint
• Destroy executes even if verification fails
• Cleanup check confirms zero tagged resources remain
• No manual SSH is required
• No AWS console edits are required
• No manual environment exports are required
• Logs are inspectable via GitHub Actions artifacts

If infrastructure remains after workflow completion, the milestone is not complete.

⸻

# Runbooks

• docs/runbooks/milestone06.md
• docs/runbooks/troubleshooting.md

⸻

# Tag

v0.6 — CI Delivery Authority & Deterministic Lifecycle

⸻


Milestone 07 — Kubernetes Runtime Authority & Helm Release Discipline (v0.7)

Goal

Move StackPilot from container orchestration by convention to runtime enforcement by Kubernetes.

This milestone proves that the platform runs as a controlled Kubernetes system with truthful health semantics, dependency-aware readiness, stable rollout behavior, and release packaging through Helm.

Kubernetes becomes the runtime authority.
Helm becomes the release authority.

The system is no longer considered correct because containers start.
It is considered correct only when the cluster admits healthy workloads, blocks unready ones, routes traffic correctly, and can recover cleanly through controlled release changes.

⸻

What This Milestone Demonstrates

• Full six-service deployment to local k3s
• In-cluster Postgres dependencies for identity-service and wallet-service
• Kubernetes Deployments and Services for all workloads
• NGINX ingress routing for customer.local, admin.local, and ops.local
• Stable service discovery through Kubernetes DNS
• Separation between process liveness (/health) and dependency truth (/ready)
• Dependency-aware readiness propagation across upstream services
• Traffic routed only to ready workloads
• Controlled rollout behavior under good and bad releases
• A repeatable Kubernetes verification path from the host
• Helm packaging of the full stack as a releasable system
• Helm install, upgrade, and rollback working locally
• Values-based environment separation for local and staged runtime definitions
• Clear separation between runtime authority (Kubernetes) and release authority (Helm)

⸻

What “Working” Means

The system is considered working only if all of the following are true:

• All six services and both Postgres dependencies run in k3s
• Kubernetes Services resolve workloads correctly by internal DNS name
• Ingress routes external traffic correctly to:
• customer.local
• admin.local
• ops.local
• /health reports process liveness only
• /ready reports dependency truth only
• If a dependency fails, upstream readiness degrades truthfully
• Unready workloads do not receive traffic
• A bad release is visibly blocked by readiness
• Verification passes through the canonical Kubernetes verification path
• Helm can install the stack cleanly
• Helm can upgrade the stack cleanly
• Helm can roll the stack back to a known-good revision
• Re-deploying from chart state behaves deterministically

If workloads are merely “Running” but readiness is dishonest, the milestone is not complete.

⸻

Runbooks

• docs/runbooks/milestone07.md
• docs/runbooks/troubleshooting.md

⸻

Tag

v0.7 — Kubernetes Runtime Authority & Helm Release Discipline

⸻