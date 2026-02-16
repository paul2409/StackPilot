## Milestone 06 — CI Delivery Authority + Deterministic Lifecycle

# Purpose

Milestone 06 establishes CI as the delivery authority for infrastructure lifecycle and runtime verification.

At this stage, CI owns:
	•	Terraform apply
	•	Remote deployment
	•	Runtime verification
	•	Terraform destroy
	•	Cleanup proof

Delivery is no longer human-driven. Infrastructure lifecycle becomes deterministic, automated, and provably clean.

This milestone introduces real AWS execution while maintaining strict cost and safety discipline.

⸻

## Scope (What This Milestone Covers)
	•	CI-driven Terraform apply
	•	CI-driven deployment to EC2
	•	Runtime verification against live infrastructure
	•	Automatic destroy on all outcomes
	•	Cleanup verification using AWS queries
	•	Concurrency locks to prevent double spending
	•	Manual trigger policy for budget control

⸻

## Non-Goals (Explicitly Out of Scope)
	•	Long-lived production infrastructure
	•	S3 backend or remote Terraform state
	•	Multi-environment separation
	•	Kubernetes or EKS
	•	GitOps or ArgoCD
	•	Auto-deploy on every push

These are intentionally deferred to later milestones.

⸻

## CI Delivery Authority Model

CI becomes a deterministic state machine.

Delivery consists of a single authoritative command:

make aws-cycle

This performs:
	1.	Terraform plan
	2.	Terraform apply
	3.	target.env export
	4.	Remote deployment
	5.	Runtime verification
	6.	Terraform destroy (always)
	7.	Cleanup verification (always)

Destroy executes even if deployment or verification fails.

Humans are optional.

⸻

Workflow Structure

Workflow file:

.github/workflows/stackpilot-delivery.yml

Trigger Policy

on:
  workflow_dispatch:

Manual execution only.

Reason:
Running this workflow provisions AWS resources and consumes budget.

⸻

## CI State Machine Model

Stage 1 — Validate

Runs:

make checks

Includes:
	•	Repo policy
	•	Secrets safety
	•	Guarantees map
	•	Python checks
	•	Terraform fmt + validate

No infrastructure is touched.

⸻

Stage 2 — Deliver

Runs:

make aws-cycle

Responsibilities:
	•	Provision EC2
	•	Deploy stack
	•	Verify runtime behavior
	•	Destroy infrastructure
	•	Prove AWS is clean

Timeouts and concurrency locks are enforced.

⸻

Runtime Verification Standard

Verification is not superficial.

verify-aws.sh must prove:
	•	Endpoint is reachable
	•	/health returns OK
	•	/ready returns OK
	•	Database schema exists
	•	Write succeeds
	•	Read succeeds
	•	API restart succeeds
	•	Data persists after restart
	•	Docker logs are collected

If any step fails:
	•	Script exits non-zero
	•	Destroy still runs
	•	Cleanup check still runs

No silent success.

⸻

## Cleanup Discipline

Cleanup proof is mandatory.

aws-clean-check.sh queries AWS directly for:
	•	EC2 instances
	•	Volumes
	•	Security groups

Filtered by tag:

project=stackpilot

Expected result:

All result tables empty.

If any resource remains:
CI fails.

This proves delivery does not leave AWS dirty.

⸻

## Cost Controls

Milestone 06 enforces:
	•	Manual trigger only
	•	Concurrency lock = 1 delivery at a time
	•	Job timeouts
	•	Always-destroy behavior
	•	Cleanup verification

Running delivery consumes AWS credits.

This milestone is budget-aware by design.

⸻

## Makefile Authority

CI does not execute raw Terraform commands.

All operations are routed through Make targets:

make aws-plan
make aws-apply
make deploy-aws
make verify-aws
make aws-destroy
make aws-cycle

If it is not in make help, it is not supported.

This preserves operator discipline and reproducibility.

⸻

## Failure Handling
	•	Failures are intentional and blocking
	•	Destroy always executes
	•	Cleanup always executes
	•	Logs are uploaded even on failure
	•	No step silently ignores errors

Delivery must either succeed cleanly or fail cleanly.

⸻

## End State Guarantees

After Milestone 06:
	•	CI is authoritative for infrastructure lifecycle
	•	Delivery is deterministic
	•	Infrastructure can be created and destroyed automatically
	•	Runtime behavior is verified against real AWS
	•	Budget exposure is controlled
	•	AWS is provably clean after each run

Milestone 06 closes the infrastructure lifecycle loop.

⸻


Milestone 06 intentionally stops after proving that:

Infrastructure can be created, verified, and destroyed safely by CI.

The system is no longer theoretical.

It executes.
