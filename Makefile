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

ROOT_DIR    := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
VAGRANT_DIR := $(ROOT_DIR)/vagrant
SCRIPTS_DIR := $(ROOT_DIR)/scripts

CORE_DIR    := $(SCRIPTS_DIR)/core
VERIFY_DIR  := $(SCRIPTS_DIR)/verify
OPS_DIR     := $(SCRIPTS_DIR)/ops
CHECKS_DIR  := $(SCRIPTS_DIR)/checks
DRILLS_DIR  := $(SCRIPTS_DIR)/drills

# Phase 2 (Milestone 04) - Terraform Structure Authority
TF_DIR      := $(ROOT_DIR)/infra/terraform
CI_LOGS_DIR := $(ROOT_DIR)/ci/logs

# ----------------------------------------------------------
# Runtime parameters (overridable)
# ----------------------------------------------------------

NODE ?= control
APP_IMAGE ?= infra-api:local

# ----------------------------------------------------------
# Phony targets (these are commands, not files)
# ----------------------------------------------------------
.PHONY: help preflight-host preflight-repo up demo demo-reviewer \
        checks check-policy check-secrets check-guarantees check-build \
        check-python check-immutable-tags check-terraform \
        tf-fmt tf-fmt-check tf-init tf-validate tf-plan tf-ci tf-exec \
        verify verify-host verify-cluster verify-build \
        logs down clean destroy \
        vm-up vm-halt vm-destroy vm-ensure-up ssh status provision \
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
	@echo "  make checks          Run all repo gates (policy + secrets + guarantees map + build)"
	@echo "  make check-policy    Run repo structure/policy gate"
	@echo "  make check-secrets   Run secrets safety gate (demo env allowlisted)"
	@echo "  make check-guarantees Run guarantees map gate"
	@echo ""
	@echo "Terraform checks (Milestone 04 Phase 2 - structure authority)"
	@echo "  make check-terraform Run Terraform fmt-check + validate (CI-safe: no apply/destroy)"
	@echo "  make tf-fmt-check    Terraform fmt check (diff output to ci/logs/)"
	@echo "  make tf-validate     Terraform validate (output to ci/logs/)"
	@echo "  make tf-plan         Terraform plan (optional local discipline; output to ci/logs/)"
	@echo "  make tf-ci           Terraform CI gates (fmt-check + validate)"
	@echo "  make tf-exec         Terraform exec discipline (init + validate + plan)"
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
	@echo "== PREFLIGHT: host (scripts/core/preflight-host.sh) =="
	@bash "$(CORE_DIR)/preflight-host.sh"

preflight-repo:
	@echo "== PREFLIGHT: repo (scripts/core/preflight-repo.sh) =="
	@bash "$(CORE_DIR)/preflight-repo.sh"


# ----------------------------------------------------------
# Golden path targets
# ----------------------------------------------------------
up: preflight-host vm-up demo

demo: preflight-host
	@echo "== DEMO: service up (scripts/core/service-up.sh) =="
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
	@echo "== CHECK: policy | scripts/checks/policy.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/policy.sh"

check-secrets: preflight-repo
	@echo "== CHECK: secrets | scripts/checks/secrets.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/secrets.sh"

check-guarantees: preflight-repo
	@echo "== CHECK: guarantees | scripts/checks/guarantees-map.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/guarantees-map.sh"

check-build: preflight-repo
	@echo "== CHECK: build | scripts/checks/build.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/build.sh"

check-python: preflight-repo
	@echo "== CHECK: python | scripts/checks/python.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/python.sh"

check-immutable-tags: preflight-repo
	@echo "== CHECK: immutable-tags | scripts/checks/immutable-tags.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/immutable-tags.sh"


# ----------------------------------------------------------
# Terraform gates (Milestone 04 Phase 2 - Structure Authority)
#
# Rule:
#   - CI must be able to run these without VirtualBox/Vagrant.
#   - No apply/destroy in CI (humans run the truth cycle).
#   - Outputs must be readable and land in ci/logs/.
# ----------------------------------------------------------
tf-fmt:
	@echo "== TF: fmt (write) | infra/terraform =="
	@terraform -chdir="$(TF_DIR)" fmt

tf-fmt-check:
	@echo "== TF: fmt (check) | infra/terraform =="
	@mkdir -p "$(CI_LOGS_DIR)"
	@terraform -chdir="$(TF_DIR)" fmt -check -diff | tee "$(CI_LOGS_DIR)/terraform-fmt.txt"

tf-init:
	@echo "== TF: init | infra/terraform =="
	@mkdir -p "$(CI_LOGS_DIR)"
	@terraform -chdir="$(TF_DIR)" init -upgrade | tee "$(CI_LOGS_DIR)/terraform-init.txt"

tf-validate: tf-init
	@echo "== TF: validate | infra/terraform =="
	@mkdir -p "$(CI_LOGS_DIR)"
	@terraform -chdir="$(TF_DIR)" validate | tee "$(CI_LOGS_DIR)/terraform-validate.txt"

# Optional local-only discipline. Keep it in the golden path, but it must remain CI-safe.
tf-plan: tf-init
	@echo "== TF: plan | infra/terraform =="
	@mkdir -p "$(CI_LOGS_DIR)"
	@terraform -chdir="$(TF_DIR)" plan -no-color | tee "$(CI_LOGS_DIR)/terraform-plan.txt"

# Phase 3 helpers:
# - tf-ci: CI-safe Terraform gates
# - tf-exec: execution discipline (still no apply/destroy)
tf-ci:
	@echo "== TF: ci (fmt-check + validate) =="
	@$(MAKE) tf-fmt-check
	@$(MAKE) tf-validate

tf-exec:
	@echo "== TF: exec (init + validate + plan) =="
	@$(MAKE) tf-init
	@$(MAKE) tf-validate
	@$(MAKE) tf-plan

check-terraform: preflight-repo
	@echo "== CHECK: terraform (fmt-check + validate) =="
	@$(MAKE) tf-ci
	@echo "PASS: terraform checks"

checks: check-policy check-secrets check-guarantees check-build check-python check-immutable-tags check-terraform


# ----------------------------------------------------------
# Verification (runtime proof)
# ----------------------------------------------------------
verify-host: preflight-host
	@echo "== VERIFY: host | scripts/verify/verify-host.sh =="
	@cd "$(ROOT_DIR)" && bash "$(VERIFY_DIR)/verify-host.sh"

verify-cluster: preflight-host
	@echo "== VERIFY: cluster | scripts/verify/verify-cluster.sh =="
	@cd "$(ROOT_DIR)" && bash "$(VERIFY_DIR)/verify-cluster.sh"

verify-build: preflight-host
	@echo "== VERIFY: build/runtime | scripts/verify/verify-build.sh =="
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

	@if [[ "$${CI_LAB_BOOTSTRAP:-0}" == "1" ]]; then \
		echo "== VERIFY: lab bootstrap =="; \
		$(MAKE) up; \
	fi

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
	@echo "== DRILL: db-ready | scripts/drills/db-ready.sh =="
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(DRILLS_DIR)/db-ready.sh"


# ----------------------------------------------------------
# Service lifecycle targets
# ----------------------------------------------------------
down: preflight-host
	@echo "== DOWN: service down (scripts/core/service-down.sh) =="
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(CORE_DIR)/service-down.sh"

clean: preflight-host
	@echo "== CLEAN: clean-room (scripts/core/clean-room.sh) =="
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" APP_IMAGE="$(APP_IMAGE)" bash "$(CORE_DIR)/clean-room.sh"

destroy: preflight-host clean vm-destroy


# ----------------------------------------------------------
# VM lifecycle (infrastructure layer)
# ----------------------------------------------------------
vm-up: preflight-host
	@echo "== VM: up (vagrant up) =="
	@cd "$(VAGRANT_DIR)" && vagrant up

vm-halt: preflight-host
	@echo "== VM: halt (vagrant halt) =="
	@cd "$(VAGRANT_DIR)" && vagrant halt

vm-destroy: preflight-host
	@echo "== VM: destroy (vagrant destroy -f) =="
	@cd "$(VAGRANT_DIR)" && vagrant destroy -f

# vm-ensure-up:
# - Boots the lab only if it is not already running.
# - Does NOT provision (no accidental re-provision each push).
# - Writes machine-readable status to ci/logs/ for debugging.
vm-ensure-up: preflight-host
	@echo "== VM: ensure-up (boot only if needed) =="
	@mkdir -p "$(CI_LOGS_DIR)"

	@cd "$(VAGRANT_DIR)" && vagrant status | tee "$(CI_LOGS_DIR)/vagrant-status.txt" >/dev/null

	@cd "$(VAGRANT_DIR)" && \
	  need_up=0; \
	  for m in control worker1 worker2; do \
	    out="$$(vagrant status "$$m" 2>&1 || true)"; \
	    if echo "$$out" | grep -qi "running"; then \
	      echo "PASS: $$m is running"; \
	    else \
	      echo "WARN: $$m is not running"; \
	      need_up=1; \
	    fi; \
	  done; \
	  if [[ "$$need_up" == "1" ]]; then \
	    echo "== VM: boot missing machines (no provision) =="; \
	    vagrant up --no-provision; \
	  else \
	    echo "PASS: all lab VMs running (no action)"; \
	  fi




# ----------------------------------------------------------
# Helpers (non-golden-path, still supported)
# ----------------------------------------------------------
logs: preflight-host
	@echo "== LOGS: tail | scripts/ops/logs.sh =="
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(OPS_DIR)/logs.sh"

ssh: preflight-host
	@echo "== SSH: node=$(NODE) | vagrant ssh $(NODE) =="
	@cd "$(VAGRANT_DIR)" && vagrant ssh "$(NODE)"

status: preflight-host
	@echo "== STATUS: vagrant status =="
	@cd "$(VAGRANT_DIR)" && vagrant status

provision: preflight-host
	@echo "== PROVISION: vagrant provision =="
	@cd "$(VAGRANT_DIR)" && vagrant provision
