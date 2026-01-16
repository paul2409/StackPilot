# StackPilot — Platform Engineering Lab
*Standard Deploys, Happy Developers*

StackPilot is a platform engineering sandbox for consistent rollouts and fast feedback. It’s a local-first lab where you practice: Linux + Vagrant → Docker → Kubernetes (k3s) → GitOps (Argo CD) → Observability (Prometheus/Grafana).

## What You’ll Build
- A reproducible 3-VM lab environment
- A Kubernetes (k3s) cluster
- CI pipelines for build/test
- GitOps-based deployment with Argo CD
- Monitoring and dashboards with Prometheus and Grafana
- Runbooks, troubleshooting notes, and controlled failure drills

## Lab Nodes (Host-only Network)
- control: 192.168.56.10
- worker1: 192.168.56.11
- worker2: 192.168.56.12

## Commands
- `make up` — boot the lab
- `make provision` — provision packages + baseline config
- `make verify` — run checks (host + VM connectivity)
- `make destroy` — tear down the lab

## Repo Structure
- `vagrant/` — VM definitions
- `scripts/` — provisioning and verification scripts
- `docs/` — runbooks and notes
- `apps/` — sample apps
- `ci/` — CI workflows

## Milestone 01 — Lab Foundation

# Goal #
Establish a reproducible local lab that all later StackPilot milestones build on.

# What This Milestone Covers #

3-node Ubuntu lab using Vagrant (control + 2 workers)

Static IP networking and hostname-based communication

Idempotent Bash provisioning on all nodes

Automated verification from host and between VMs

Initial runbook created from a controlled failure

# Lab Topology #

control — 192.168.56.10

worker1 — 192.168.56.11

worker2 — 192.168.56.12

# Golden Commands #

make up — bring up the lab

make provision — provision all nodes

make verify — validate lab health

make destroy — tear down the lab

# Tag #

v0.1 — Lab Foundation