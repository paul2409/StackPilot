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
#
# ==========================================================
# QUICK EXAMPLES (copy/paste)
#
# Golden path:
#   make up        -> boots VMs, starts services
#   make verify    -> proves system state
#   make down      -> stops services (keeps images/volumes)
#
# Reviewer flow:
#   make demo-reviewer -> clean-room -> demo -> verify
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
#
# Example override (only if your compose image differs):
#   APP_IMAGE=stackpilot/infra-api:local make clean
APP_IMAGE ?= infra-api:local


# ----------------------------------------------------------
# Phony targets (these are commands, not files)
# ----------------------------------------------------------
.PHONY: help preflight up demo demo-reviewer verify logs down clean destroy \
        vm-up vm-halt vm-destroy ssh status provision


# ----------------------------------------------------------
# help: prints the supported commands and how to use them
#
# Examples:
#   make help
# ----------------------------------------------------------
help:
	@echo "StackPilot (Golden Path)"
	@echo ""
	@echo "Golden path"
	@echo "  make up              Boot VMs + start services on NODE (default: control)"
	@echo "  make demo            Start services on NODE (canonical entrypoint)"
	@echo "  make verify          Run verification suite (host + cluster + service checks)"
	@echo "  make down            Stop services on NODE (containers removed, images/volumes kept)"
	@echo ""
	@echo "Reviewer proof"
	@echo "  make demo-reviewer   Clean-room -> demo -> verify (anti-stale proof)"
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
	@echo "  APP_IMAGE=infra-api:local make clean"
	@echo "  make destroy"


# ----------------------------------------------------------
# preflight: Milestone 03 - host prerequisite checks
#
# Purpose:
#   Fail fast on the HOST before doing any VM work.
#   This prevents confusing mid-flight failures (missing vagrant,
#   missing provider, wrong repo shape, etc.)
#
# Examples:
#   make preflight
# ----------------------------------------------------------
preflight:
	@bash "$(CORE_DIR)/preflight.sh"


# ----------------------------------------------------------
# Golden path targets
# ----------------------------------------------------------

# up:
#   1) preflight checks on host
#   2) boot VMs (vagrant up)
#   3) start services on selected NODE via service-up.sh
#
# Examples:
#   make up
#   NODE=worker1 make up
up: preflight vm-up demo

# demo:
#   Start services on selected NODE using the canonical script.
#   The script is responsible for compose build/up and for
#   any VM-side execution discipline (/vagrant enforcement).
#
# Examples:
#   make demo
#   NODE=worker1 make demo
demo: preflight
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(CORE_DIR)/service-up.sh"

# demo-reviewer:
#   Reviewer proof flow:
#     1) clean-room teardown (remove containers + app image + cache)
#     2) rebuild via demo
#     3) verify end-to-end
#
# Examples:
#   make demo-reviewer
#   NODE=worker1 make demo-reviewer
demo-reviewer: preflight
	@$(MAKE) clean NODE="$(NODE)" APP_IMAGE="$(APP_IMAGE)"
	@$(MAKE) demo  NODE="$(NODE)"
	@$(MAKE) verify NODE="$(NODE)"


# ----------------------------------------------------------
# Verification
# ----------------------------------------------------------

# verify:
#   Runs verification layers in order:
#     1) host-side checks (reachability, TCP/HTTP)
#     2) cluster checks (hostname resolution / VM connectivity)
#     3) VM-side checks (build/image/runtime truth)
#
# Rule:
#   If verify fails, the system is not "working" regardless of
#   manual checks or ad-hoc SSH success.
#
# Examples:
#   make verify
#   NODE=worker1 make verify
verify: preflight
	@cd "$(ROOT_DIR)" && bash "$(VERIFY_DIR)/verify-host.sh"
	@cd "$(ROOT_DIR)" && bash "$(VERIFY_DIR)/verify-cluster.sh"
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(VERIFY_DIR)/verify-build.sh"


# ----------------------------------------------------------
# Service lifecycle targets
# ----------------------------------------------------------

# down:
#   Stops services (containers only).
#   Keeps images and volumes so restart is fast.
#
# Examples:
#   make down
#   NODE=worker1 make down
down: preflight
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(CORE_DIR)/service-down.sh"

# clean:
#   Clean-room teardown:
#     - docker compose down (containers removed)
#     - delete ONLY the application image (APP_IMAGE)
#     - prune unused build cache
#
# This forces the next demo to rebuild from source.
#
# Examples:
#   make clean
#   NODE=worker1 make clean
#   APP_IMAGE=infra-api:local make clean
clean: preflight
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" APP_IMAGE="$(APP_IMAGE)" bash "$(CORE_DIR)/clean-room.sh"

# destroy:
#   Full reset:
#     - clean-room teardown first (so rebuild claims stay true)
#     - destroy VMs for a total clean slate
#
# Examples:
#   make destroy
destroy: preflight clean vm-destroy


# ----------------------------------------------------------
# VM lifecycle (infrastructure layer)
# ----------------------------------------------------------

# vm-up:
#   Create and boot all VMs (control/worker1/worker2)
#
# Examples:
#   make vm-up
vm-up:
	@cd "$(VAGRANT_DIR)" && vagrant up

# vm-halt:
#   Gracefully power off all VMs
#
# Examples:
#   make vm-halt
vm-halt:
	@cd "$(VAGRANT_DIR)" && vagrant halt

# vm-destroy:
#   Permanently delete all VMs
#
# Examples:
#   make vm-destroy
vm-destroy:
	@cd "$(VAGRANT_DIR)" && vagrant destroy -f


# ----------------------------------------------------------
# Helpers (non-golden-path, still supported)
# ----------------------------------------------------------

# logs:
#   Stream compose logs from inside NODE (script must handle VM exec)
#
# Examples:
#   make logs
#   NODE=worker1 make logs
logs: preflight
	@cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(OPS_DIR)/logs.sh"

# ssh:
#   SSH into the selected NODE using vagrant
#
# Examples:
#   make ssh
#   NODE=worker2 make ssh
ssh: preflight
	@cd "$(VAGRANT_DIR)" && vagrant ssh "$(NODE)"

# status:
#   Show Vagrant VM status
#
# Examples:
#   make status
status: preflight
	@cd "$(VAGRANT_DIR)" && vagrant status

# provision:
#   Re-run provisioning scripts (Week 1 behavior)
#   Later milestones may replace this with Ansible.
#
# Examples:
#   make provision
provision: preflight
	@cd "$(VAGRANT_DIR)" && vagrant provision
