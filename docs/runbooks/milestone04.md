# Milestone 04 — CI Authority + Terraform Structure Discipline

## Purpose

Milestone 04 establishes **CI as the enforcement authority** for repository correctness and **Terraform as the structural authority** for infrastructure definitions.

At this stage, CI does **not** own runtime environments or infrastructure lifecycle. Its job is to prevent bad changes from being merged and to enforce deterministic, reviewable infrastructure code.

This milestone intentionally avoids self-hosted runners, VM orchestration, or cloud resources. Stability and enforcement come first.

---

## Scope (What This Milestone Covers)

* GitHub-hosted CI as the single required gate
* Terraform project structure and version pinning
* Deterministic Terraform formatting and validation
* Makefile as the only supported operator interface
* Mandatory branch protection and merge enforcement
* CI artifacts captured for inspection on failure

---

## Non-Goals (Explicitly Out of Scope)

* Terraform apply/destroy in CI
* Runtime verification in CI
* VM or container lifecycle ownership
* AWS or cloud resources
* Kubernetes execution

These are intentionally deferred to later milestones.

---

## Terraform Structure Authority

Terraform is introduced as a **first-class project**, not as ad-hoc scripts.

### Directory Layout

```
infra/terraform/
├── README.md
├── versions.tf
├── main.tf
├── variables.tf
└── outputs.tf
```

### Guarantees

* Terraform core version is pinned (`required_version`)
* Provider versions are pinned (`required_providers`)
* No implicit or “latest” dependencies
* Structure exists even if resources are minimal

This prevents:

* “Works on my machine” drift
* Silent provider upgrades
* Undocumented infra assumptions

---

## CI Enforcement Model

### CI Runner

* GitHub-hosted runner (`ubuntu-latest`)
* No dependency on local machines
* Always available

### CI Responsibilities

CI enforces:

* Repository policy checks
* Secrets safety
* Guarantees map integrity
* Python checks
* Immutable image tagging rules
* Terraform formatting and validation

CI explicitly does **not**:

* Apply infrastructure
* Destroy infrastructure
* Manage runtime state

---

## Terraform CI Gates

Terraform is enforced through Make targets, never direct CLI usage.

### CI-Safe Targets

```
make check-terraform
make tf-ci
```

These run:

* `terraform fmt -check`
* `terraform validate`

Outputs are written to:

```
ci/logs/
├── terraform-fmt.txt
└── terraform-validate.txt
```

Failures are visible both in CI logs and as downloadable artifacts.

---

## Human Execution Discipline

Terraform execution exists, but is **human-driven** at this stage.

### Supported Manual Commands

```
make tf-init
make tf-validate
make tf-plan
```

These commands:

* Prove Terraform can initialize and plan deterministically
* Do not modify infrastructure
* Are not run automatically by CI

This establishes execution discipline without granting CI destructive authority.

---

## Makefile as the Single Interface

All operations are exposed via the Makefile.

Rules:

* No raw `terraform` commands in documentation
* No ad-hoc CI commands
* If it’s not in `make help`, it’s not supported

This ensures:

* Reproducibility
* Reviewer clarity
* Operator safety

---

## Branch Protection & Enforcement

### Required Protections

* `main` branch is protected
* Direct pushes to `main` are blocked
* Pull requests are mandatory
* Hosted CI job is required to pass before merge

### Enforcement Proof

Milestone 04 is considered complete only after confirming:

* A failing CI run blocks merge
* A passing CI run allows merge
* Logs are always uploaded under `ci/logs/`

---

## Failure Handling

* CI failures are intentional and blocking
* Logs are uploaded even on failure
* No silent or ignored errors
* Failures must be fixed, not bypassed

---

## End State Guarantees

After Milestone 04:

* CI is authoritative for repo correctness
* Terraform is structurally sound and pinned
* Bad infrastructure code cannot be merged
* Reviewers can inspect failures easily
* The system is boring, predictable, and safe

This milestone forms the **enforcement foundation** for all future cloud, Kubernetes, and SRE work.

---

## What Comes Next

Milestone 05 will introduce **real infrastructure** (AWS) where Terraform execution becomes meaningful.

At that point:

* Terraform execution in CI becomes valuable
* Plans target real resources
* Infrastructure lifecycle discipline expands

Milestone 04 intentionally stops before that boundary.

This ensures a solid, reviewable foundation before complexity increases.
---