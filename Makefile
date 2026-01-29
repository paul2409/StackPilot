## ==========================================================
# StackPilot Makefile - Golden Path
#
# This Makefile is the "operator interface" for the repo.
# If a command is not exposed here, it is not part of the
# supported golden path.
#
# Key principles:
#  - main commands are simple and deterministic
#  - host preflight fails fast before doing expensive work
#  - service operations happen via scripts (not ad-hoc docker)
#  - NODE allows running the service on control/worker1/worker2
#  - drills are explicit and destructive (never part of verify)
#
# Milestone 03 Item 4 + Item 5
#  - Item 4 (Secrets): secrets gate must be runnable via Make
#  - Item 5 (Guarantees): guarantees map gate must be runnable via Make
#  - Checks must run BEFORE runtime verification
# ==========================================================
# QUICK EXAMPLES (copy/paste)
#
# Golden path:
#   make up        -> boots VMs, starts services
#   make verify    -> runs checks first, then proves system state
#   make down      -> stops services (keeps images/volumes)
#
# Reviewer flow:
#   make demo-reviewer -> clean-room -> demo -> verify
#
# Failure drills (Milestone 03 Phase 2):
#   make drill-db-ready          -> controlled DB outage proof (host-driven)
#   NODE=worker1 make drill-db-ready
#
# Multi-node usage:
#   NODE=worker1 make demo
#   NODE=worker1 make verify
#   NODE=worker2 make logs
#
# Clean-room / reviewer proof:
#   make demo-reviewer
#   NODE=worker1 make demo-reviewer
#
# Image override (only if your compose `image:` differs):
#   APP_IMAGE=infra-api:local make clean
#
# Full reset:
#   make destroy
# ==========================================================

.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

# ----------------------------------------------------------
# Paths (resolved from this Makefile location)
# ----------------------------------------------------------

# Absolute path to the repository root (folder containing this Makefile)
ROOT_DIR    := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# Vagrant folder (contains Vagrantfile + VM topology)
VAGRANT_DIR := $(ROOT_DIR)/vagrant

# Scripts folder (organized by purpose)
SCRIPTS_DIR := $(ROOT_DIR)/scripts

# Script subfolders (stable interface)
CORE_DIR    := $(SCRIPTS_DIR)/core
VERIFY_DIR  := $(SCRIPTS_DIR)/verify
OPS_DIR     := $(SCRIPTS_DIR)/ops
CHECKS_DIR  := $(SCRIPTS_DIR)/checks

# Drills folder (failure + recovery proofs)
DRILLS_DIR  := $(SCRIPTS_DIR)/drills


# ----------------------------------------------------------
# Runtime parameters (overridable)
# ----------------------------------------------------------

# Which VM to run service commands on.
# Examples:
#   NODE=worker1 make demo
#   NODE=worker2 make logs
NODE ?= control

# The application image name removed during clean-room.
# Must match the compose file `image:` for the API service.
# Milestone 03 rule: avoid :latest.
APP_IMAGE ?= infra-api:local


# ----------------------------------------------------------
# Phony targets (these are commands, not files)
# ----------------------------------------------------------
.PHONY: help preflight-host preflight-repo up demo demo-reviewer \
        checks check-policy check-secrets check-guarantees \
        verify verify-host verify-cluster verify-build \
        logs down clean destroy \
        vm-up vm-halt vm-destroy ssh status provision \
        drills drill-db-ready


# ----------------------------------------------------------
# help: prints the supported commands and how to use them
# ----------------------------------------------------------
help:
	@echo "StackPilot (Golden Path)"
	@echo ""
	@echo "Golden path"
	@echo "  make up              Boot VMs + start services on NODE (default: control)"
	@echo "  make demo            Start services on NODE (canonical entrypoint)"
	@echo "  make verify          Run checks first, then run verification suite"
	@echo "  make down            Stop services on NODE (containers removed, images/volumes kept)"
	@echo ""
	@echo "Repo checks (Milestone 03 gates)"
	@echo "  make checks          Run all repo gates (policy + secrets + guarantees map)"
	@echo "  make check-policy    Run repo structure/policy gate"
	@echo "  make check-secrets   Run secrets safety gate (demo env allowlisted)"
	@echo "  make check-guarantees Run guarantees map gate"
	@echo ""
	@echo "Reviewer proof"
	@echo "  make demo-reviewer   Clean-room -> demo -> verify (anti-stale proof)"
	@echo ""
	@echo "Failure drills (Milestone 03 Phase 2)"
	@echo "  make drills          List available drills"
	@echo "  make drill-db-ready  Controlled DB outage drill (readiness honesty + recovery proof)"
	@echo ""
	@echo "Ops helpers"
	@echo "  make logs            Tail service logs on NODE"
	@echo "  make clean           Clean-room teardown on NODE (remove containers + app image + prune build cache)"
	@echo "  make destroy         Clean-room + destroy VMs (clean slate)"
	@echo ""
	@echo "VM helpers"
	@echo "  make ssh             SSH into NODE (NODE=control|worker1|worker2)"
	@echo "  make status          Vagrant status"
	@echo "  make provision       Vagrant provision (Week 1 path; later replaced by Ansible)"
	@echo ""
	@echo "Examples:"
	@echo "  make up"
	@echo "  NODE=worker1 make demo"
	@echo "  NODE=worker1 make verify"
	@echo "  make demo-reviewer"
	@echo "  NODE=worker1 make demo-reviewer"
	@echo "  make drill-db-ready"
	@echo "  NODE=worker1 make drill-db-ready"
	@echo "  APP_IMAGE=infra-api:local make clean"
	@echo "  make destroy"


# ----------------------------------------------------------
# preflight: prerequisite checks
#   - preflight-repo: CI-safe (no vagrant/virtualbox requirement)
#   - preflight-host: requires VM tooling
# ----------------------------------------------------------
preflight-host:
	@bash "$(CORE_DIR)/preflight-host.sh"

preflight-repo:
	@bash "$(CORE_DIR)/preflight-repo.sh"


# ----------------------------------------------------------
# Golden path targets
# ----------------------------------------------------------
up: preflight-host vm-up demo

demo: preflight-host
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(CORE_DIR)/service-up.sh"

demo-reviewer:
	@$(MAKE) clean  NODE="$(NODE)" APP_IMAGE="$(APP_IMAGE)"
	@$(MAKE) demo   NODE="$(NODE)"
	@$(MAKE) verify NODE="$(NODE)"


# ----------------------------------------------------------
# Checks (Milestone 03 Item 4 + Item 5)
#
# Rule:
#   Checks must run BEFORE runtime verification.
#   Checks are non-destructive and must never run drills.
# ----------------------------------------------------------
check-policy: preflight-repo
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/policy.sh"

check-secrets: preflight-repo
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/secrets.sh"

check-guarantees: preflight-repo
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/guarantees-map.sh"

checks: check-policy check-secrets check-guarantees


# ----------------------------------------------------------
# Verification (runtime proof)
# ----------------------------------------------------------
verify-host: preflight-host
	@cd "$(ROOT_DIR)" && bash "$(VERIFY_DIR)/verify-host.sh"

verify-cluster: preflight-host
	@cd "$(ROOT_DIR)" && bash "$(VERIFY_DIR)/verify-cluster.sh"

verify-build: preflight-host
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(VERIFY_DIR)/verify-build.sh"

# ----------------------------------------------------------
# verify:
#   Phase 1 rule:
#     - In GitHub-hosted CI (no VMs), verify runs repo gates only.
#     - Locally (or on a self-hosted runner with VMs), verify runs full suite.
#
# Detection:
#   - Full runtime requires Vagrant + running VMs, which hosted runners won't have.
# ----------------------------------------------------------
verify: preflight-repo
	@echo "== VERIFY: start =="

	@echo "== VERIFY: repo checks =="
	@$(MAKE) checks

	@# Optional lab bootstrap (self-hosted CI or local operator)
	@if [[ "$${CI_LAB_BOOTSTRAP:-0}" == "1" ]]; then \
		echo "== VERIFY: lab bootstrap =="; \
		$(MAKE) vm-up; \
	fi

	@# Capability check: runtime requires Vagrant + VMs
	@if ! command -v vagrant >/dev/null 2>&1; then \
		echo "== VERIFY: runtime skipped (no vagrant available) =="; \
		echo "PASS: verification complete (checks-only)"; \
		exit 0; \
	fi

	@echo "== VERIFY: host verification =="
	@$(MAKE) verify-host

	@echo "== VERIFY: cluster verification =="
	@$(MAKE) verify-cluster

	@echo "== VERIFY: build/runtime verification =="
	@$(MAKE) verify-build

	@echo "== VERIFY: PASS =="


# ----------------------------------------------------------
# Failure drills (Milestone 03 Phase 2)
# ----------------------------------------------------------
drills:
	@echo "Available drills:"
	@echo "  make drill-db-ready   (DB down readiness honesty + recovery proof)"

drill-db-ready: preflight-host
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(DRILLS_DIR)/db-ready.sh"


# ----------------------------------------------------------
# Service lifecycle targets
# ----------------------------------------------------------
down: preflight-host
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(CORE_DIR)/service-down.sh"

clean: preflight-host
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" APP_IMAGE="$(APP_IMAGE)" bash "$(CORE_DIR)/clean-room.sh"

destroy: preflight-host clean vm-destroy


# ----------------------------------------------------------
# VM lifecycle (infrastructure layer)
# ----------------------------------------------------------
vm-up: preflight-host
	@cd "$(VAGRANT_DIR)" && vagrant up

vm-halt: preflight-host
	@cd "$(VAGRANT_DIR)" && vagrant halt

vm-destroy: preflight-host
	@cd "$(VAGRANT_DIR)" && vagrant destroy -f


# ----------------------------------------------------------
# Helpers (non-golden-path, still supported)
# ----------------------------------------------------------
logs: preflight-host
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(OPS_DIR)/logs.sh"

ssh: preflight-host
	@cd "$(VAGRANT_DIR)" && vagrant ssh "$(NODE)"

status: preflight-host
	@cd "$(VAGRANT_DIR)" && vagrant status

provision: preflight-host
	@cd "$(VAGRANT_DIR)" && vagrant provision