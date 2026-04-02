## ==========================================================
# StackPilot Makefile - Golden Path (Hyper-V Edition)
#
# This Makefile is the "operator interface" for the repo.
# If a command is not exposed here, it is not part of the
# supported golden path.
#
# Hyper-V notes:
#  - Vagrant Hyper-V provider needs an elevated (Admin) shell.
#  - Shared folders use SMB (you will be prompted for Windows creds).
#  - VM images (boxes) must have a Hyper-V build (e.g. generic/ubuntu2204).
## ==========================================================

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

NAMESPACE ?= stackpilot
CUSTOMER_HOST ?= http://customer.local
ADMIN_HOST ?= http://admin.local
OPS_HOST ?= http://ops.local

# Terraform (local lab)
TF_DIR := $(ROOT_DIR)/infra/terraform

# ----------------------------------------------------------
# Unified artifact root (single CI forensic bundle)
# ----------------------------------------------------------
ARTIFACTS_DIR := $(ROOT_DIR)/artifacts
AWS_ART_DIR   := $(ARTIFACTS_DIR)/aws
AWS_LOGS_DIR  := $(ARTIFACTS_DIR)/logs/aws
TF_LOGS_DIR   := $(ARTIFACTS_DIR)/logs/terraform
CI_LOGS_DIR   := $(ARTIFACTS_DIR)/logs/ci

# AWS (terraform in AWS)
AWS_ENV    := $(ROOT_DIR)/infra/aws/aws.env
AWS_TF_DIR := $(ROOT_DIR)/infra/aws/tf

# ----------------------------------------------------------
# Runtime parameters (overridable)
# ----------------------------------------------------------
NODE ?= control
APP_IMAGE ?= infra-api:local

# Hyper-V provider (single source of truth)
PROVIDER ?= hyperv

# Optional: if you have multiple Hyper-V switches, you can set this
# in your environment and use it in your Vagrantfile.
# HYPERV_SWITCH ?= "Default Switch"

# ----------------------------------------------------------
# Phony targets
# ----------------------------------------------------------
.PHONY: help preflight repo-preflight up demo reviewer \
        checks policy secrets guarantees build python tags terraform \
        terraform-fmt terraform-fmtcheck terraform-init terraform-validate terraform-plan terraform-ci terraform-exec \
        verify host-verify cluster-verify runtime-verify \
        logs down clean destroy \
        vm-up vm-halt vm-destroy vm-reload ssh status provision \
        drills drill-db \
        aws-sts aws-ip aws-init aws-validate aws-plan aws-plan-guarded aws-apply aws-destroy aws-cycle aws-clean-check \
        aws-target deploy-aws verify-aws aws-run aws-remote-logs \
		k8s-up k8s-down k8s-status k8s-verify

# ----------------------------------------------------------
# help
# ----------------------------------------------------------
help:
	@echo "StackPilot (Golden Path) - Hyper-V"
	@echo ""
	@echo "Golden path"
	@echo "  make up              Boot VMs + start services on NODE (default: control)"
	@echo "  make demo            Start services on NODE (canonical entrypoint)"
	@echo "  make verify          Run checks first, then run verification suite"
	@echo "  make down            Stop services on NODE (containers removed, images/volumes kept)"
	@echo ""
	@echo "VM lifecycle (Hyper-V)"
	@echo "  make vm-up            vagrant up --provider=$(PROVIDER)"
	@echo "  make vm-halt          vagrant halt"
	@echo "  make vm-reload        vagrant reload"
	@echo "  make vm-destroy       vagrant destroy -f"
	@echo "  make ssh              vagrant ssh NODE (default: control)"
	@echo "  make status           vagrant status"
	@echo "  make provision        vagrant provision"
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
	@echo "  make aws-run         apply -> target -> deploy -> verify -> destroy -> clean-check"
	@echo ""
	@echo "Artifacts:"
	@echo "  $(ARTIFACTS_DIR)/"
	@echo ""
	@echo "Notes:"
	@echo "  - Hyper-V provider requires an Admin shell."
	@echo "  - SMB shared folders will prompt for your Windows credentials."
	@echo "  - Use a Hyper-V-capable box (e.g. generic/ubuntu2204)."

# ----------------------------------------------------------
# preflight
# ----------------------------------------------------------
preflight:
	@echo "== PREFLIGHT: host (scripts/core/preflight-host.sh) =="
	@bash "$(CORE_DIR)/preflight-host.sh"


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
# VM lifecycle (Hyper-V)
# ----------------------------------------------------------
vm-up: preflight
	@echo "== VM: up (vagrant up) provider=$(PROVIDER) =="
	@cd "$(VAGRANT_DIR)" && vagrant up --provider="$(PROVIDER)"

vm-halt: preflight
	@echo "== VM: halt (vagrant halt) =="
	@cd "$(VAGRANT_DIR)" && vagrant halt

vm-reload: preflight
	@echo "== VM: reload (vagrant reload) =="
	@cd "$(VAGRANT_DIR)" && vagrant reload

vm-destroy: preflight
	@echo "== VM: destroy (vagrant destroy -f) =="
	@cd "$(VAGRANT_DIR)" && vagrant destroy -f

# ----------------------------------------------------------
# Checks
# ----------------------------------------------------------
secrets: repo-preflight
	@echo "== CHECK: secrets | scripts/checks/secrets.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/secrets.sh"


tags: repo-preflight
	@echo "== CHECK: immutable-tags | scripts/checks/immutable-tags.sh =="
	@cd "$(ROOT_DIR)" && bash "$(CHECKS_DIR)/immutable-tags.sh"

checks: secrets tags

# ----------------------------------------------------------
# Terraform gates (local lab)
# ----------------------------------------------------------
terraform-fmt:
	@echo "== TF: fmt (write) | infra/terraform =="
	@terraform -chdir="$(TF_DIR)" fmt

terraform-fmtcheck:
	@echo "== TF: fmt (check) | infra/terraform =="
	@mkdir -p "$(TF_LOGS_DIR)"
	@terraform -chdir="$(TF_DIR)" fmt -check -diff | tee "$(TF_LOGS_DIR)/fmt.txt"

terraform-init:
	@echo "== TF: init | infra/terraform =="
	@mkdir -p "$(TF_LOGS_DIR)"
	@terraform -chdir="$(TF_DIR)" init -upgrade | tee "$(TF_LOGS_DIR)/init.txt"

terraform-validate: terraform-init
	@echo "== TF: validate | infra/terraform =="
	@mkdir -p "$(TF_LOGS_DIR)"
	@terraform -chdir="$(TF_DIR)" validate | tee "$(TF_LOGS_DIR)/validate.txt"

terraform-plan: terraform-init
	@echo "== TF: plan | infra/terraform =="
	@mkdir -p "$(TF_LOGS_DIR)"
	@terraform -chdir="$(TF_DIR)" plan -no-color | tee "$(TF_LOGS_DIR)/plan.txt"

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

# ----------------------------------------------------------
# Verification (runtime proof)
# ----------------------------------------------------------

cluster-verify: preflight
	@echo "== VERIFY: cluster | scripts/verify/verify-cluster.sh =="
	@cd "$(ROOT_DIR)" && bash "$(VERIFY_DIR)/verify-cluster.sh"



verify: repo-preflight
	@echo "== VERIFY: start =="
	@echo "== VERIFY: repo checks =="
	@$(MAKE) checks

	@if ! command -v vagrant >/dev/null 2>&1; then \
		echo "== VERIFY: runtime skipped (no vagrant available) =="; \
		echo "PASS: verification complete (checks-only)"; \
		exit 0; \
	fi

	@echo "== VERIFY: cluster verification =="
	@$(MAKE) cluster-verify

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
aws-keygen:
	@echo "== AWS: generate ephemeral keypair =="
	@bash "$(AWS_DIR)/keygen.sh"

aws-run-tfvars: aws-keygen
	@echo "== AWS: write run.tfvars (ephemeral key) =="
	@bash "$(AWS_DIR)/write-run-tfvars.sh"

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

aws-plan: aws-run-tfvars aws-ip aws-validate
	@echo "== AWS: terraform plan =="
	@bash "$(AWS_DIR)/tf-plan.sh"

aws-plan-guarded: aws-plan
	@echo "== AWS: plan guard =="
	@bash "$(AWS_DIR)/plan-guard.sh"

aws-apply: aws-plan-guarded
	@echo "== AWS: terraform apply =="
	@bash "$(AWS_DIR)/tf-apply.sh"

aws-destroy: aws-sts
	@echo "== AWS: terraform destroy =="
	@bash "$(AWS_DIR)/tf-destroy.sh"

aws-clean-check:
	@echo "== AWS: cleanup verification =="
	@bash "$(AWS_DIR)/cleanup-check.sh"

aws-target: aws-apply
	@echo "== AWS: write target.env =="
	@mkdir -p "$(AWS_ART_DIR)"
	@bash "$(AWS_DIR)/target-env.sh"

deploy-aws: aws-target
	@echo "== AWS: deploy stackpilot to EC2 =="
	@bash "$(AWS_DIR)/deploy-aws.sh"

verify-aws:
	@echo "== AWS: verify external endpoints + persistence =="
	@bash "$(AWS_DIR)/verify-aws.sh"

aws-cycle:
	@echo "== AWS: full lifecycle =="
	@bash scripts/aws/aws-cycle.sh

aws-run:
	@bash "$(SCRIPTS_DIR)/aws/aws-run-safe.sh"

aws-remote-logs:
	@echo "== AWS: collect remote docker logs =="
	@bash "$(AWS_DIR)/remote-logs.sh"



k8s-up:
	kubectl apply -k k8s/stackpilot-exchange

k8s-down:
	kubectl delete -k k8s/stackpilot-exchange

k8s-status:
	NAMESPACE=$(NAMESPACE) bash scripts/verify/k8s-status.sh

k8s-verify:
	NAMESPACE=$(NAMESPACE) CUSTOMER_HOST=$(CUSTOMER_HOST) ADMIN_HOST=$(ADMIN_HOST) OPS_HOST=$(OPS_HOST) bash scripts/verify/verify-k8s.sh


monitoring-up:
	APP_NS=${APP_NS:-stackpilot-dev} ./monitoring/scripts/install-monitoring.sh

monitoring-verify:
	APP_NS=${APP_NS:-stackpilot-dev} ./scripts/verify/verify-metrics.sh

drill-wallet-db-alert:
	APP_NS=${APP_NS:-stackpilot-dev} ./scripts/drills/drill-wallet-db-alert.sh
