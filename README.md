StackPilot — Platform Engineering Lab

Standard Deploys, Happy Developers

StackPilot is a local-first Platform Engineering + SRE lab built as a provable system, not a demo.

Every milestone is accepted only when its guarantees are executable and verified, not assumed.

⸻

Lab Topology (Host-only Network)

control   — 192.168.56.10  
worker1   — 192.168.56.11  
worker2   — 192.168.56.12  

	•	Ubuntu 22.04 LTS on all nodes
	•	Static IP + hostname identity
	•	External verification from host

⸻

Golden Commands (Canonical)

Only supported operator interface:

make up
make demo
make verify
make down

Clean-room flows:

make clean
make demo-reviewer
make destroy

If make verify fails → system is NOT working.

⸻

Repository Structure

.github/        → CI automation  
.vscode/        → editor config  
apps/           → sample services  
argocd/         → gitops apps  
artifacts/      → release tracking  
ci/             → ci outputs  
docs/           → runbook docs  
helm/           → chart templates  
infra/          → infra config  
k8s/            → raw manifests  
scripts/        → ops scripts  
services/       → service code  
tmp/            → temp files  
vagrant/        → vm setup  

.gitignore      → ignore rules  
Makefile        → command runner  
README.md       → project overview

Rules:
	•	lifecycle scripts → mutate state
	•	verify scripts → assert only
	•	clean scripts → remove all implicit state

⸻

Project Philosophy
	•	correctness > features
	•	verification > assumption
	•	recovery > success path
	•	deterministic rebuild > convenience

⸻

Milestone 01 — Lab Foundation (v0.1)

Goal: Deterministic 3-VM lab

Proves:
	•	reproducible VMs
	•	stable identity
	•	host ↔ VM + VM ↔ VM connectivity
	•	idempotent provisioning
	•	verification-defined correctness

Working = make verify passes

⸻

Milestone 02 — Docker Runtime Contracts (v0.2)

Goal: Real service behavior under Docker

Proves:
	•	strict health vs readiness separation
	•	dependency-aware behavior (Postgres)
	•	failure degrades, not crashes
	•	host-driven lifecycle
	•	multi-VM portability

Working =
	•	TCP + HTTP verified
	•	readiness reflects dependencies
	•	persistence survives restart

⸻

Milestone 03 — Operational Discipline (v0.3)

Goal: Remove ambiguity from execution

Proves:
	•	single Makefile interface
	•	mandatory clean-room rebuild
	•	no stale state reuse
	•	deterministic multi-VM behavior

Working =
	•	make clean → make demo → make verify always consistent

⸻

Milestone 04 — CI Authority (v0.4)

Goal: CI enforces correctness

Proves:
	•	PR-gated validation
	•	Makefile-only execution
	•	repo vs runtime checks separation
	•	deterministic cleanup

Working =
	•	CI blocks invalid changes
	•	logs explain failures

⸻

Milestone 05 — AWS Deployment (v0.5)

Goal: Extend guarantees to cloud

Proves:
	•	Terraform-only infra
	•	artifact-driven targeting (target.env)
	•	same readiness semantics as local
	•	deterministic apply → verify → destroy

Working =
	•	no console edits
	•	clean destroy leaves no resources

⸻

Milestone 06 — CI Delivery Lifecycle (v0.6)

Goal: CI owns infra lifecycle

Proves:
	•	CI apply → deploy → verify → destroy
	•	always-destroy behavior
	•	cleanup verification
	•	budget control (manual trigger + locks)

Working =
	•	full AWS cycle runs without human intervention

⸻

Milestone 07 — Kubernetes + Helm Authority (v0.7)

Goal: Kubernetes enforces runtime truth

Proves:
	•	6-service system in k3s
	•	ingress routing (customer/admin/ops)
	•	readiness-driven traffic control
	•	Helm as release authority
	•	rollback via Helm

Working =
	•	unready services receive no traffic
	•	bad releases are blocked

⸻


Milestone 08 — GitOps & Multi-Environment Promotion (v0.8)

Goal

Move deployment authority into Git and prove controlled promotion across dev and staging with reliable rollback.

⸻

What This Milestone Demonstrates

• Git as the source of truth
• Argo CD as reconciler (no manual deploys)
• Dev and staging as real, separate environments
• CI builds images once (SHA-tagged)
• Dev deploys first, staging receives promoted artifact
• Environment separation via values files
• Drift detection and self-healing
• Rollback via Git revert
• End-to-end failure → recovery proof

⸻

What “Working” Means

• Git changes trigger deployment automatically
• Dev receives new SHA first
• Staging deploys the same SHA after promotion
• No manual kubectl required
• Drift is corrected automatically
• Failures are visible
• Git revert restores system
• Dev failure does not impact staging

⸻

Runbooks

• docs/runbooks/milestone08.md
• docs/runbooks/troubleshooting.md

⸻

Tag

v0.8 — GitOps & Multi-Environment Promotion

⸻