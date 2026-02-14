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