ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
VAGRANT_DIR := $(ROOT_DIR)/vagrant
SCRIPTS_DIR := $(ROOT_DIR)/scripts

.PHONY: up halt destroy status reload ssh-control ssh-worker1 ssh-worker2 provision verify \
        vm-up vm-halt vm-destroy service-up service-down

# -----------------------------
# Golden path: bring system up
# -----------------------------
up: vm-up service-up

vm-up:
	cd $(VAGRANT_DIR) && vagrant up

# Starts the Docker Compose stack on control (host-driven)
service-up:
	cd "$(ROOT_DIR)" && bash "$(SCRIPTS_DIR)/service-up.sh"

# -----------------------------
# Bring system down safely
# -----------------------------
halt: service-down vm-halt

vm-halt:
	cd $(VAGRANT_DIR) && vagrant halt

destroy: service-down vm-destroy

vm-destroy:
	cd $(VAGRANT_DIR) && vagrant destroy -f

# Stops the Docker Compose stack on control (host-driven)
service-down:
	cd "$(ROOT_DIR)" && bash "$(SCRIPTS_DIR)/service-down.sh"

# -----------------------------
# Convenience targets (unchanged)
# -----------------------------
status:
	cd $(VAGRANT_DIR) && vagrant status

reload:
	cd $(VAGRANT_DIR) && vagrant reload

ssh-control:
	cd $(VAGRANT_DIR) && vagrant ssh control

ssh-worker1:
	cd $(VAGRANT_DIR) && vagrant ssh worker1

ssh-worker2:
	cd $(VAGRANT_DIR) && vagrant ssh worker2

# Run provisioning without always rebooting VMs
provision:
	cd $(VAGRANT_DIR) && vagrant provision

# -----------------------------
# Verification (unchanged)
# -----------------------------
verify:
	@echo "Running verification from repo root: $(ROOT_DIR)"
	cd "$(ROOT_DIR)" && bash "$(SCRIPTS_DIR)/verify-host.sh"
	cd "$(ROOT_DIR)" && bash "$(SCRIPTS_DIR)/verify-cluster.sh"
