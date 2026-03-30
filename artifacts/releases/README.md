# StackPilot Release Artifact Truth

This directory makes artifact identity visible and deliberate.

It does not replace Helm values or Argo CD Applications.
It complements them by recording the intended release artifact identity for each environment.

## Purpose

When artifact promotion becomes real, the repo must answer:

- What image artifacts is dev supposed to run?
- What image artifacts is staging supposed to run?
- What is the current promotion candidate?

## Rules

1. No floating tags like latest.
2. Prefer immutable identity:
   - best: digest
   - very good: sha-<commit>
   - acceptable early: semver paired with sha
3. Staging should not receive a newly rebuilt image when promoting.
   It should receive the same artifact dev already validated.

## Relationship to the rest of the repo

- helm/stackpilot/ = deployment packaging truth
- argocd/ = environment contract truth
- artifacts/releases/ = release artifact visibility truth

## Current milestone position

For local M8, this is a lightweight release metadata layer.
It is intentionally simple and human-readable.
Later, this can evolve into:
- images.lock.yaml
- digest-pinned manifests
- release notes per milestone tag
- CI-generated promotion metadata
