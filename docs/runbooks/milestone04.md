Got it. Below is the edited M4 internal execution phases with those missing “glue” items placed exactly where they belong, and with self-hosted runner explicitly introduced at the right phase for VM bring-up.

MILestone 04 — Internal Execution Phases (Operator View)

Phase 1 — CI Authority Without Provisioning
Goal: CI becomes an authority over correctness, but does not create/destroy the lab.

What this phase proves:
• CI is enforcing, not decorative
• CI failure blocks merges (PR gate)
• CI calls only supported interfaces (Make targets)
• Exit codes define truth (no “manual override”)

What CI does here:
• actions/checkout
• minimal tool bootstrap needed to run verification (make, bash)
• run make verify
• upload verification logs as artifacts (so failures are inspectable)

New items introduced here (supporting pieces):
• Artifact/log retention: upload verify.log and any generated reports (if present)
• Tool installation hygiene (minimal): ensure make exists; print versions for debugging
• Baseline CI safety: no secrets printed, no env dump

What CI does not do:
• no Terraform apply/destroy
• no VM bring-up / tear-down
• no “rebuild the lab” responsibilities

Exit condition:
• Breaking verification in a PR blocks merge
• Fixing it makes CI green
• CI produces artifacts that let a reviewer understand failures without rerunning locally

—

Phase 2 — Terraform as Structure Authority (Still Human-Run Apply)
Goal: Terraform becomes the declared source of truth for lab structure, while humans still run apply/destroy.

What this phase proves:
• Lab structure is codified and reviewable
• Terraform state is real and predictable
• Destroy/recreate cycles are deterministic
• CI can validate Terraform quality without provisioning

What Terraform introduces here:
• Terraform project structure conventions (e.g., infra/ or terraform/)
• Standard commands wrapped by Make targets (example intent):
– tf-fmt, tf-validate, tf-plan
• Version pinning for Terraform (required):
– fixed Terraform version (and provider versions if applicable)
• State discipline (local-first is OK):
– state file treated as authoritative
– documented “clean destroy” behavior

What CI does here:
• terraform fmt check
• terraform validate
• (optional) terraform plan (only if it’s safe in your local-first design)
• upload plan/validate outputs as artifacts

New items introduced here (supporting pieces):
• Tool version pinning: Terraform version locked (and documented)
• Terraform structure discipline: folder layout + Make targets + consistent entrypoints
• No provisioning in CI yet: CI enforces correctness of Terraform code, not execution

Exit condition:
• terraform fmt/validate is clean in CI
• Humans can destroy and recreate lab from Terraform intent reliably
• Docs match the Terraform truth (no drift between “what we say” and “what it builds”)

—

Phase 3 — CI + Terraform End-to-End (Self-Hosted Runner, Full Lab Lifecycle)
Goal: A machine can build, verify, and tear down the lab using only supported interfaces.

Runner strategy (locked by you):
• Use a self-hosted GitHub Actions runner on the same host that runs VirtualBox/Vagrant.
• This phase is where VM bring-up becomes part of CI truth.

What this phase proves:
• System is automatable end-to-end
• Clean-room is enforceable by a machine
• No human trust is required to rebuild proof

What CI does here (end-to-end):
• checkout
• tool bootstrap (pinned versions): Terraform + Vagrant/VirtualBox tooling + required utils
• terraform apply (or vagrant bring-up if that’s still the substrate) via Make targets only
• run make demo-reviewer
• run make verify
• always run terraform destroy (or make destroy)

New items introduced here (supporting pieces):
• Runner strategy: self-hosted runner is mandatory for VM lifecycle
• Concurrency control: one run owns the lab at a time (avoid collisions)
• Log artifacts expanded: upload verify logs + terraform/apply logs + key state evidence
• Strict entrypoints: CI must call only Make targets (no ad-hoc shell provisioning)

Exit condition:
• CI can start from nothing and complete full cycle: create → demo-reviewer → verify → destroy
• CI failure still results in teardown (no leaked state)
• Re-running CI produces the same results (deterministic behavior)

—

Phase 4 — Failure-Safe Enforcement (No Leaks, No Collisions, Honest Cleanup)
Goal: Even under failure, the system remains safe, deterministic, and self-cleaning.

What this phase proves:
• CI doesn’t leak infra or leave VMs/containers running
• Partial failures do not leave residue
• Concurrent CI runs don’t corrupt lab state
• Cleanup is guaranteed and observable

What CI enforces here:
• if: always() cleanup paths for destroy
• concurrency groups to prevent simultaneous ownership
• explicit state discipline checks (no “half-owned” Terraform/Vagrant state)
• artifact proof of cleanup (logs show destroy executed even on failure)

New items introduced here (supporting pieces):
• Cleanup guarantees become non-negotiable
• Concurrency is hardened and tested (intentional collision attempts)
• “Fail-on-purpose” tests: you deliberately break a step and confirm teardown still happens

Exit condition:
• Forced CI failures still tear down cleanly
• Back-to-back CI runs always start clean
• Collisions are prevented or safely canceled without corrupting state

—

If you want, next I’ll produce the Phase 1 “exact checklist” that you’ll implement first (what files change, what targets exist, what artifacts to upload), and a Phase 1 pass/fail definition you can’t wiggle around.

One follow-up so I wire it correctly: in Phase 3, do you want CI to call “make up / make destroy” (Vagrant truth), or “make tf-apply / make tf-destroy” (Terraform truth), with Vagrant called only inside Terraform if needed?   lets begin with phase 1 