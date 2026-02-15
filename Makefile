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
#   make reviewer -> clean-room -> demo -> verify
#
# Failure drills:
#   make drill-db
#   NODE=worker1 make drill-db
#
# Multi-node usage:
#   NODE=worker1 make demo
#   NODE=worker1 make verify
#   NODE=worker2 make logs
#
# Clean-room / reviewer proof:
#   make reviewer
#   NODE=worker1 make reviewer
#
# Full reset:
#   make destroy
#
# AWS usage:
#   make aws-sts
#   make aws-ip
#   make aws-plan-guarded
#   make aws-apply
#   make aws-target
#   make deploy-aws
#   make verify-aws
#   make aws-destroy
#   make aws-run
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
AWS_DIR     := $(SCRIPTS_DIR)/aws

# Terraform (local lab)
TF_DIR      := $(ROOT_DIR)/infra/terraform
CI_LOGS_DIR := $(ROOT_DIR)/ci/logs

# AWS (terraform in AWS)
AWS_ENV      := $(ROOT_DIR)/infra/aws/aws.env
AWS_TF_DIR   := $(ROOT_DIR)/infra/aws/tf
AWS_LOGS_DIR := $(ROOT_DIR)/ci/logs/aws

# ----------------------------------------------------------
# Runtime parameters (overridable)
# ----------------------------------------------------------
NODE ?= control
APP_IMAGE ?= infra-api:local

# ----------------------------------------------------------
# Phony targets
# ----------------------------------------------------------
.PHONY: help preflight repo-preflight up demo reviewer \
        checks policy secrets guarantees build python tags terraform \
        terraform-fmt terraform-fmtcheck terraform-init terraform-validate terraform-plan terraform-ci terraform-exec \
        verify host-verify cluster-verify runtime-verify \
        logs down clean destroy \
        vm-up vm-halt vm-destroy ssh status provision \
        drills drill-db \
        aws-sts aws-ip aws-init aws-validate aws-plan aws-plan-guarded aws-apply aws-destroy aws-cycle aws-clean-check \
        aws-target deploy-aws verify-aws aws-run


# ----------------------------------------------------------
# help
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
	@echo "Reviewer proof"
	@echo "  make reviewer        Clean-room -> demo -> verify (anti-stale proof)"
	@echo ""
	@echo "Repo gates"
	@echo "  make checks          Run all repo gates (policy + secrets + guarantees map + build)"
	@echo ""
	@echo "Terraform gates (local lab)"
	@echo "  make terraform       Terraform gates (fmt-check + validate)"
	@echo ""
	@echo "AWS helpers"
	@echo "  make aws-sts         Validate AWS identity/profile/region (scripts/aws/sts-checks.sh)"
	@echo "  make aws-ip          Refresh operator IP (scripts/ops/update-ip.sh)"
	@echo "  make aws-plan        Terraform plan (AWS)"
	@echo "  make aws-plan-guarded Plan + forbid expensive resources"
	@echo "  make aws-apply       Terraform apply (AWS)"
	@echo "  make aws-target      Write artifacts/aws/target.env (scripts/aws/target-env.sh)"
	@echo "  make deploy-aws      Rsync repo + docker compose up on EC2 (scripts/aws/deploy-aws.sh)"
	@echo "  make verify-aws      External verification + persistence (scripts/aws/verify-aws.sh)"
	@echo "  make aws-destroy     Terraform destroy (AWS)"
	@echo "  make aws-clean-check Prove no leftover AWS resources (scripts/aws/cleanup-check.sh)"
	@echo "  make aws-run         apply -> target -> deploy -> verify -> destroy -> clean-check"
	@echo ""
	@echo "Examples:"
	@echo "  make up"
	@echo "  make reviewer"
	@echo "  make aws-run"


# ----------------------------------------------------------
# preflight
# ----------------------------------------------------------
preflight:
	@echo "== PREFLIGHT: host (scripts/core/preflight-host.sh) =="
	@bash "$(CORE_DIR)/preflight-host.sh"

repo-preflight:
	@echo "== PREFLIGHT: repo (scripts/core/preflight-repo.sh) =="
	@bash "$(CORE_DIR)/preflight-repo.sh"


# ----------------------------------------------------------
# Golden path targets
# ----------------------------------------------------------
up: preflight vm-up demo

demo: preflight
	@echo "== DEMO: service up (scripts/core/service-up.sh) =="
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(CORE_DIR)/service-up.sh"

reviewer:
	@$(MAKE) clean  NODE="$(NODE)" APP_IMAGE="$(APP_IMAGE)"
	@$(MAKE) demo   NODE="$(NODE)"
	@$(MAKE) verify NODE="$(NODE)"


# ----------------------------------------------------------
# Checks
# ----------------------------------------------------------
policy: repo-preflight
	@echo "== CHECK: policy | scripts/checks/policy.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/policy.sh"

secrets: repo-preflight
	@echo "== CHECK: secrets | scripts/checks/secrets.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/secrets.sh"

guarantees: repo-preflight
	@echo "== CHECK: guarantees | scripts/checks/guarantees-map.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/guarantees-map.sh"

build: repo-preflight
	@echo "== CHECK: build | scripts/checks/build.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/build.sh"

python: repo-preflight
	@echo "== CHECK: python | scripts/checks/python.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/python.sh"

tags: repo-preflight
	@echo "== CHECK: immutable-tags | scripts/checks/immutable-tags.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/immutable-tags.sh"


# ----------------------------------------------------------
# Terraform gates (local lab)
# ----------------------------------------------------------
terraform-fmt:
	@echo "== TF: fmt (write) | infra/terraform =="
	@terraform -chdir="$(TF_DIR)" fmt

terraform-fmtcheck:
	@echo "== TF: fmt (check) | infra/terraform =="
	@mkdir -p "$(CI_LOGS_DIR)"
	@terraform -chdir="$(TF_DIR)" fmt -check -diff | tee "$(CI_LOGS_DIR)/terraform-fmt.txt"

terraform-init:
	@echo "== TF: init | infra/terraform =="
	@mkdir -p "$(CI_LOGS_DIR)"
	@terraform -chdir="$(TF_DIR)" init -upgrade | tee "$(CI_LOGS_DIR)/terraform-init.txt"

terraform-validate: terraform-init
	@echo "== TF: validate | infra/terraform =="
	@mkdir -p "$(CI_LOGS_DIR)"
	@terraform -chdir="$(TF_DIR)" validate | tee "$(CI_LOGS_DIR)/terraform-validate.txt"

terraform-plan: terraform-init
	@echo "== TF: plan | infra/terraform =="
	@mkdir -p "$(CI_LOGS_DIR)"
	@terraform -chdir="$(TF_DIR)" plan -no-color | tee "$(CI_LOGS_DIR)/terraform-plan.txt"

terraform-ci:
	@echo "== TF: ci (fmt-check + validate) =="
	@$(MAKE) terraform-fmtcheck
	@$(MAKE) terraform-validate

terraform-exec:
	@echo "== TF: exec (init + validate + plan) =="
	@$(MAKE) terraform-init
	@$(MAKE) terraform-validate
	@$(MAKE) terraform-plan

terraform: repo-preflight
	@echo "== CHECK: terraform (fmt-check + validate) =="
	@$(MAKE) terraform-ci
	@echo "PASS: terraform checks"

checks: policy secrets guarantees build python tags terraform


# ----------------------------------------------------------
# Verification (runtime proof)
# ----------------------------------------------------------
host-verify: preflight
	@echo "== VERIFY: host | scripts/verify/verify-host.sh =="
	@cd "$(ROOT_DIR)" && bash "$(VERIFY_DIR)/verify-host.sh"

cluster-verify: preflight
	@echo "== VERIFY: cluster | scripts/verify/verify-cluster.sh =="
	@cd "$(ROOT_DIR)" && bash "$(VERIFY_DIR)/verify-cluster.sh"

runtime-verify: preflight
	@echo "== VERIFY: build/runtime | scripts/verify/verify-build.sh =="
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(VERIFY_DIR)/verify-build.sh"

verify: repo-preflight
	@echo "== VERIFY: start =="
	@echo "== VERIFY: repo checks =="
	@$(MAKE) checks

	@if ! command -v vagrant >/dev/null 2>&1; then \
		echo "== VERIFY: runtime skipped (no vagrant available) =="; \
		echo "PASS: verification complete (checks-only)"; \
		exit 0; \
	fi

	@echo "== VERIFY: host verification =="
	@$(MAKE) host-verify

	@echo "== VERIFY: cluster verification =="
	@$(MAKE) cluster-verify

	@echo "== VERIFY: build/runtime verification =="
	@$(MAKE) runtime-verify

	@echo "== VERIFY: PASS =="


# ----------------------------------------------------------
# Failure drills
# ----------------------------------------------------------
drills:
	@echo "Available drills:"
	@echo "  make drill-db"

drill-db: preflight
	@echo "== DRILL: db-ready | scripts/drills/db-ready.sh =="
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(DRILLS_DIR)/db-ready.sh"


# ----------------------------------------------------------
# Service lifecycle targets
# ----------------------------------------------------------
down: preflight
	@echo "== DOWN: service down (scripts/core/service-down.sh) =="
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(CORE_DIR)/service-down.sh"

clean: preflight
	@echo "== CLEAN: clean-room (scripts/core/clean-room.sh) =="
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" APP_IMAGE="$(APP_IMAGE)" bash "$(CORE_DIR)/clean-room.sh"

destroy: preflight clean vm-destroy


# ----------------------------------------------------------
# VM lifecycle
# ----------------------------------------------------------
vm-up: preflight
	@echo "== VM: up (vagrant up) =="
	@cd "$(VAGRANT_DIR)" && vagrant up

vm-halt: preflight
	@echo "== VM: halt (vagrant halt) =="
	@cd "$(VAGRANT_DIR)" && vagrant halt

vm-destroy: preflight
	@echo "== VM: destroy (vagrant destroy -f) =="
	@cd "$(VAGRANT_DIR)" && vagrant destroy -f


# ----------------------------------------------------------
# Helpers
# ----------------------------------------------------------
logs: preflight
	@echo "== LOGS: tail | scripts/ops/logs.sh =="
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(OPS_DIR)/logs.sh"

ssh: preflight
	@echo "== SSH: node=$(NODE) | vagrant ssh $(NODE) =="
	@cd "$(VAGRANT_DIR)" && vagrant ssh "$(NODE)"

status: preflight
	@echo "== STATUS: vagrant status =="
	@cd "$(VAGRANT_DIR)" && vagrant status

provision: preflight
	@echo "== PROVISION: vagrant provision =="
	@cd "$(VAGRANT_DIR)" && vagrant provision


# ----------------------------------------------------------
# AWS commands (no console clicking)
# ----------------------------------------------------------
aws-sts:
	@echo "== AWS: STS identity check =="
	@bash "$(AWS_DIR)/sts-checks.sh"

aws-ip:
	@echo "== AWS: update operator IP =="
	@bash "$(OPS_DIR)/update-ip.sh"

aws-init: aws-sts
	@echo "== AWS: terraform init =="
	@bash "$(AWS_DIR)/tf-init.sh"

aws-validate: aws-init
	@echo "== AWS: terraform validate =="
	@bash "$(AWS_DIR)/tf-validate.sh"

aws-plan: aws-ip aws-validate
	@echo "== AWS: terraform plan =="
	@bash "$(AWS_DIR)/tf-plan.sh"

aws-plan-guarded: aws-plan
	@echo "== AWS: plan guard =="
	@bash "$(AWS_DIR)/plan-guard.sh"

aws-apply: aws-plan
	@echo "== AWS: terraform apply =="
	@bash "$(AWS_DIR)/tf-apply.sh"

aws-destroy: aws-sts
	@echo "== AWS: terraform destroy =="
	@bash "$(AWS_DIR)/tf-destroy.sh"

aws-clean-check:
	@echo "== AWS: cleanup verification =="
	@bash "$(AWS_DIR)/cleanup-check.sh"

aws-cycle:
	@echo "== AWS: full cycle (apply -> destroy -> clean-check) =="
	@bash "$(AWS_DIR)/tf-apply.sh"
	@bash "$(AWS_DIR)/tf-destroy.sh"
	@bash "$(AWS_DIR)/cleanup-check.sh"
	@echo "PASS: aws-cycle"

aws-target: aws-apply
	@echo "== AWS: write target.env =="
	@bash "$(AWS_DIR)/target-env.sh"

deploy-aws: aws-target
	@echo "== AWS: deploy stackpilot to EC2 =="
	@bash "$(AWS_DIR)/deploy-aws.sh"

verify-aws:
	@echo "== AWS: verify external endpoints + persistence =="
	@bash "$(AWS_DIR)/verify-aws.sh"

aws-run:
	@bash "$(SCRIPTS_DIR)/aws/aws-run-safe.sh"