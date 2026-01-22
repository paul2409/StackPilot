StackPilot — Platform Engineering Lab
Standard Deploys, Happy Developers

StackPilot is a local-first Platform Engineering and SRE lab.
It is operated as a system with explicit guarantees, verification, and recovery paths — not as a tutorial, demo, or sandbox.

The repository is built incrementally through milestones.
Each milestone is merged only when its guarantees hold and are provable.

⸻

Lab Topology (Host-only Network)

control   — 192.168.56.10
worker1   — 192.168.56.11
worker2   — 192.168.56.12


⸻

Golden Commands (Canonical)

These are the only supported ways to operate the lab.

make destroy
make up
make provision
make verify

If make verify does not PASS, the system is not considered working.

Manual SSH success or ad-hoc checks do not override verification failure.

⸻

Repository Structure

vagrant/   — VM definitions and topology
scripts/   — provisioning, lifecycle, and verification
docs/      — runbooks, guarantees, and operational notes
apps/      — sample services used to prove platform behavior
ci/        — CI workflows (introduced in later milestones)


⸻

Milestone 01 — Lab Foundation (v0.1)

Goal

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

Runbooks
	•	docs/runbooks/milestone01.md
	•	docs/runbooks/troubleshooting.md

If a failure cannot be recovered using the runbooks, the documentation is improved before moving forward.

Tag

v0.1 — Lab Foundation (Infrastructure Truth)

⸻

Milestone 02 — Dockerized Service Contracts & Host-Driven Operations (v0.2)

Goal

Prove that the lab can run a production-behaving service with explicit lifecycle control, truthful health semantics, and predictable failure behavior — all operated from the host.

What This Milestone Demonstrates
	•	Docker as the enforced runtime (no “it runs locally” assumptions)
	•	A real API service with strict startup and runtime contracts
	•	Separation of liveness (/health) and readiness (/ready)
	•	A real external dependency (Postgres)
	•	Failure-first behavior that degrades safely instead of crashing
	•	Explicit TCP-level network verification before HTTP checks
	•	Host-driven lifecycle control (make up / verify / halt / destroy)
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

Operational Runbooks
	•	docs/runbooks/milestone02.md
	•	docs/runbooks/troubleshooting.md

Runbooks document:
	•	the golden path,
	•	expected failure behavior,
	•	recovery steps,
	•	and verification boundaries.

Tag

v0.2 — Dockerized Service Contracts & Host-Driven Operations

⸻

Project Philosophy

StackPilot prioritizes operational correctness over feature scope.

The applications are intentionally simple.
The value of the project lies in guarantees, verification, failure behavior, and recoverability, not in application complexity.

⸻