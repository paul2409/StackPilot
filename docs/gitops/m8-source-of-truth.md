# M8 Source Of Truth

## Goal

M8 establishes Git as the normal deployment authority for local StackPilot.

## Runtime truth is split into 3 layers

### Layer 1 - Deployment packaging truth

helm/stackpilot/

This layer defines:
- chart identity
- templates
- shared defaults
- dev overrides
- staging overrides

### Layer 2 - Environment contract truth

argocd/stackpilot-dev.yaml
argocd/stackpilot-staging.yaml

This layer defines:
- which repo is watched
- which revision is watched
- which path is authoritative
- which values files are used
- which namespace is targeted

### Layer 3 - Release artifact visibility truth

artifacts/releases/

This layer records:
- which image references dev is intended to run
- which image references staging is intended to run
- what artifact identity is being promoted

## Operational rule

Normal deployment change begins in Git.
The cluster is not normal deployment authority.
Manual kubectl patching is drift, not standard delivery.

## Rollback rule

Rollback is Git revert followed by reconciliation.
