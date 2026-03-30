# M8 Artifact Truth

## Why this exists

Once artifact promotion is part of M8, image identity must stop being vague.

Bad examples:
- latest
- whatever got rebuilt most recently
- whatever image I think is running

Good examples:
- ghcr.io/paul2409/customer-portal:sha-abc123
- ghcr.io/paul2409/customer-portal@sha256:...

## Current rule

For now, the repo must make artifact identity visible.
That is why artifacts/releases/ exists.

## Promotion rule

Promotion should move a known artifact forward.
Staging should not consume a fresh rebuild if dev already validated a known image.

## M8 scope

This is not full production supply-chain hardening yet.
At this stage, we are locking:
- explicit image references
- registry discipline
- visible release metadata
- the habit of promoting known artifacts

## Later hardening

Later phases can add:
- digest pinning everywhere
- CI-generated lockfiles
- image scanning
- signing
- SBOM generation
- stronger promotion gates
