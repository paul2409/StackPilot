# Terraform (Phase 2: Structure Authority)

This folder is the canonical Terraform entrypoint for StackPilot.

## What it owns (Phase 2)
- Project structure, conventions, and pinned versions.
- Terraform quality gates (fmt/validate) enforced by CI.

## What it does NOT do yet
- No apply/destroy in CI.
- No real infrastructure management in Phase 2.

## How to run (humans only)
From repo root:

- Format (check only):
  make tf-fmt-check

- Validate:
  make tf-validate

- Optional local workflow:
  make tf-init
  make tf-plan
