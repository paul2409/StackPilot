# StackPilot — Platform Engineering Lab
Standard Deploys, Happy Developers

StackPilot is a local-first Platform Engineering and SRE lab.
It is operated as a system with explicit guarantees, verification, and recovery paths — not as a tutorial or sandbox.

The repository is built incrementally through milestones. Each milestone is merged only when its guarantees hold.

---

## Lab Topology (Host-only Network)

control   — 192.168.56.10  
worker1   — 192.168.56.11  
worker2   — 192.168.56.12  

---

## Golden Commands (Canonical)

These are the only supported ways to operate the lab.

make destroy  
make up  
make provision  
make verify  

If `make verify` does not PASS, the system is not considered working.

---

## Repo Structure

vagrant/   — VM definitions  
scripts/   — provisioning and verification  
docs/      — runbooks and operational notes  
apps/      — sample applications (later milestones)  
ci/        — CI workflows (later milestones)  

---

## Milestone 01 — Lab Foundation (v0.1)

### Goal
Establish a deterministic, reproducible 3-VM lab that all later StackPilot milestones depend on.

### What This Milestone Demonstrates
• Reproducible environments built from zero  
• Stable node identity (hostnames and IPs do not drift)  
• Host → VM connectivity verified externally  
• VM ↔ VM connectivity verified by hostname  
• Idempotent provisioning safe to re-run  
• Verification-defined correctness (not manual checks)  
• Executable runbooks and a controlled failure drill  

### What “Working” Means
“Working” is defined only by:

make verify

Manual SSH success or ad-hoc checks do not override verification failure.

### Runbooks
docs/runbooks/milestone01.md  
docs/runbooks/troubleshooting.md  

If a failure cannot be recovered using the runbooks, the documentation is improved before moving forward.

### Tag
v0.1 — Lab Foundation
