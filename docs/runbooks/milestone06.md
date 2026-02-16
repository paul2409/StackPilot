Perfect. Milestone 06 is where your repo stops being “a lab that can be run” and becomes “a system CI can deliver end-to-end with zero humans.” That’s a huge jump, and it needs to be staged so you don’t accidentally build a pipeline that “kind of works once.”

Here’s a phased breakdown that’s detailed enough to execute, but still clean.

Phase 0 — Hard Preconditions And Guardrails (you don’t skip this)
Goal: make the pipeline safe to run repeatedly without surprise cost or random failures.

What must be true before we touch CI:

1. Terraform is already cleanly destroyable from local. No drift. No manual edits in AWS console.
2. Your AWS target variables are standardized (region, instance type, tags, etc.) and loaded from one place.
3. One command locally can do the whole flow end-to-end (apply → deploy → verify → destroy). CI will just “copy” that behavior.
4. A hard cost guard exists. Example: only t3.micro allowed, only 1 instance, only 1 security group, only your minimal VPC pieces, explicit tags, and a forced destroy on failure.

Deliverables:

* make e2e-local (or equivalent) that runs: apply → deploy → verify → destroy, and always destroys even if verify fails.
* make verify-aws that proves the system works on the EC2 host (not “CI runner”).
* a “trap-based” cleanup pattern in scripts so destroy happens on any error.

Phase 1 — Split Responsibilities Into Tight Scripts (CI should not contain logic)
Goal: CI should be orchestration only. All logic lives in scripts/ + Makefile targets.

You create 4 “authoritative” steps, each as a Make target that CI calls:

1. make tf-apply-aws

* runs terraform init/validate/plan/apply
* writes outputs into an artifact file (example: artifacts/aws/target.env)
* target.env contains SSH host, user, key path usage pattern, API URL, etc.

2. make deploy-aws

* uses artifacts/aws/target.env
* SSH into EC2
* installs docker + docker compose (or uses your bootstrap)
* transfers compose/env files OR pulls repo
* starts the docker-compose stack
* blocks until health checks pass (don’t sleep blindly; poll health)

3. make verify-aws

* uses artifacts/aws/target.env
* runs your verification suite against the deployed endpoint (health, readiness, key API checks, DB reachable, container identity if relevant)
* stores logs as artifacts

4. make tf-destroy-aws

* always runs
* destroys terraform resources
* verifies “nothing left” (at least: terraform state empty + optional AWS sanity check)

Deliverables:

* scripts/aws/export-target-env.sh (writes the env file from terraform outputs)
* scripts/aws/remote-bootstrap.sh (idempotent)
* scripts/aws/remote-deploy.sh (idempotent)
* scripts/aws/remote-verify.sh (assertive, not fragile)
* scripts/aws/remote-logs.sh (pull docker logs on failure)

Key rule: idempotency. If deploy runs twice, it should not break.

Phase 2 — CI As A Deterministic State Machine (not “steps that happen”)
Goal: GitHub Actions (or whatever CI) becomes a state machine with hard cleanup rules.

Pipeline stages (conceptual):
A) Validate stage (cheap + fast)

* lint / formatting / policy checks
* terraform validate + fmt check (but no apply)
* docker build verification (if you enforce this)
  This stage blocks delivery.

B) Delivery stage (the real milestone)

* tf-apply-aws
* deploy-aws
* verify-aws
* tf-destroy-aws (always, even if deploy or verify fails)

The “always destroy” pattern is the heart of this milestone.
In GitHub Actions that typically means destroy is in a step with “always()” or in a dedicated job that runs no matter what, but uses the same artifacts/state.

Deliverables:

* .github/workflows/m6-cd.yml with:

  * explicit concurrency lock (prevents two deliveries racing and doubling cost)
  * timeout limits (prevents hanging and burning cash)
  * forced destroy on any outcome
  * artifacts upload (plans, logs, target.env, docker logs)

Phase 3 — Secret Handling That Won’t Leak Or Rot
Goal: CI can SSH and run Terraform without humans, safely.

You need:

1. AWS credentials for CI

* minimal permissions (at least for the resources you create)
* stored as GitHub Secrets (or OIDC role assumption if you go cleaner)

2. SSH access pattern

* Either bake a key pair into Terraform and store private key as CI secret, or generate in CI and push public key during apply.
* You must avoid printing private key in logs. Ever.

3. No “manual copy/paste” of target info

* target.env comes from terraform output automatically.
* All scripts read target.env.

Deliverables:

* a “no-echo” pattern in scripts (set +x off around sensitive ops)
* a single secrets contract documented in README: required secrets and what they do

Phase 4 — Verification That Actually Proves Delivery (not just “it responded”)
Goal: verification catches fake-success states.

Minimum verification set for Milestone 06:

* endpoint reachable
* /health returns OK
* /ready returns OK
* DB is actually used (not just “container running”)
* restart behavior: restart API container and prove recovery
* pull docker logs and attach as artifacts

A strong extra (very worth it):

* verify build identity: confirm the image tag/version on EC2 matches what CI intended (prevents “latest drift” problems)

Deliverables:

* scripts/verify/verify-aws.sh that fails hard with useful output
* artifacts for logs always uploaded

Phase 5 — Cost And Cleanup Proof (the “humans are optional” claim)
Goal: you can show, with evidence, that it never leaves AWS dirty.

Hard requirements:

* concurrency lock = 1 delivery at a time
* timeouts on long steps
* destroy always runs
* post-destroy “sanity proof” (at least terraform shows no resources; optionally AWS query by tag)

Deliverables:

* tags like Project=StackPilot, Milestone=06, RunID=<github_run_id>
* scripts/aws/assert-clean.sh (optional but powerful)

Phase 6 — Release Controls (so CI isn’t accidentally burning your $134)
Goal: make delivery controlled and intentional.

Options:

1. Only run on workflow_dispatch (manual trigger in GitHub UI) while you’re cost constrained.
2. Run on merges to main, but require approval via environments (GitHub Environments gates).
3. Run nightly? Not recommended with $134 constraint.

Deliverables:

* explicit trigger policy in workflow
* documentation: “when this runs, it costs money”

Phase 7 — Exit Package (the proof that you finished)
Goal: you can show the milestone is completed without explaining verbally.

You’ll produce:

* A single workflow run link showing: apply → deploy → verify → destroy succeeded
* Logs/artifacts proving verify ran on the deployed public endpoint
* Screenshot or text snippet of the CI summary (clean and readable)
* A short “How to rerun” section for reviewers

Now, two questions so I don’t build this in the wrong direction:

1. Which CI are you using for Milestone 06 right now—GitHub Actions or GitLab CI?
2. For AWS auth in CI, are you already set up with OIDC role assumption, or are you using access keys in secrets?
