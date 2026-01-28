# StackPilot Versions (Phase 1 · Step 4)

This document defines the version surface StackPilot depends on for deterministic rebuilds.
Any version change must be intentional and recorded here.

⸻

## 1) Vagrant / VM Base

- Vagrantfile: `vagrant/Vagrantfile`
- Base box: `ubuntu/jammy64`

Notes:
- The base box is explicitly named to prevent OS drift.
- Box upgrades are allowed only as deliberate changes and must be recorded here.

Evidence (host):
- `vagrant --version`
- `vagrant box list | grep jammy`
- `VBoxManage --version`

⸻

## 2) Docker Install (Inside VMs)

Install method:
- Docker Engine and Docker Compose plugin installed via the **official Docker APT repository** on Ubuntu Jammy.

Pinning status:
- Docker Engine: **floating**
- Docker Compose plugin: **floating**

Rationale:
- Exact package versions are not pinned at this stage.
- Determinism is enforced via:
  - documented install method
  - verification scripts
  - mandatory clean-room rebuilds (Milestone 03)

Evidence (inside VM):
- `docker --version`
- `docker compose version`

⸻

## 3) API Container Base Image

Dockerfile:
- Path: `apps/mock-exchange/Dockerfile`

Base image:
- `python:3.12.4-slim`

Rules:
- No `latest`
- No major-only tags (`python:3.12`)
- Base image must be an exact, immutable tag

Evidence:
- `grep '^FROM' apps/mock-exchange/Dockerfile`

⸻

## 4) Application Image (Local Build)

- Image name: `infra-api:local`
- Built locally via Docker Compose
- Image deletion is mandatory in clean-room rebuilds (Milestone 03)

⸻

## 5) Quick Version Snapshot (Copy / Paste)

Host:
- `vagrant --version`
- `VBoxManage --version`

Inside VM:
- `docker --version`
- `docker compose version`

Container base:
- `grep '^FROM' apps/mock-exchange/Dockerfile`
