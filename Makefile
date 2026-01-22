ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
VAGRANT_DIR := $(ROOT_DIR)/vagrant
SCRIPTS_DIR := $(ROOT_DIR)/scripts

.PHONY: up halt destroy status reload ssh-control ssh-worker1 ssh-worker2 provision verify \
        vm-up vm-halt vm-destroy service-up service-down \
        up-worker1 halt-worker1 verify-worker1

# -----------------------------
# Golden path: VMs + services (default: control)
# -----------------------------
up: vm-up service-up

vm-up:
	cd $(VAGRANT_DIR) && vagrant up

# Start services on selected node (default: control)
service-up:
	cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(SCRIPTS_DIR)/service-up.sh"

# -----------------------------
# Down: stop services then halt/destroy VMs
# -----------------------------
halt: service-down vm-halt

vm-halt:
	cd $(VAGRANT_DIR) && vagrant halt

destroy: service-down vm-destroy

vm-destroy:
	cd $(VAGRANT_DIR) && vagrant destroy -f

# Stop services on selected node (default: control)
service-down:
	cd "$(ROOT_DIR)" && NODE="$(NODE)" bash "$(SCRIPTS_DIR)/service-down.sh"

# -----------------------------
# Convenience targets
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

provision:
	cd $(VAGRANT_DIR) && vagrant provision

# -----------------------------
# Verify (SERVICE_IP defaults inside script to control)
# -----------------------------
verify:
	cd "$(ROOT_DIR)" && SERVICE_IP="$(SERVICE_IP)" bash "$(SCRIPTS_DIR)/verify-host.sh"
	cd "$(ROOT_DIR)" && bash "$(SCRIPTS_DIR)/verify-cluster.sh" 
# -----------------------------
# Worker1 specific targets
# -----------------------------
up-worker1:
	cd $(VAGRANT_DIR) && vagrant up worker1
halt-worker1:
	cd $(VAGRANT_DIR) && vagrant halt worker1
verify-worker1:
	cd "$(ROOT_DIR)" && SERVICE_IP="192.168.56.11" bash "$(SCRIPTS_DIR)/verify-host.sh"