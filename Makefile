ROOT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
VAGRANT_DIR := $(ROOT_DIR)/vagrant
SCRIPTS_DIR := $(ROOT_DIR)/scripts

.PHONY: up halt destroy status reload ssh-control ssh-worker1 ssh-worker2 provision verify 

up:
	cd $(VAGRANT_DIR) && vagrant up

halt:
	cd $(VAGRANT_DIR) && vagrant halt

destroy:
	cd $(VAGRANT_DIR) && vagrant destroy -f

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

verify:
	@echo "Running verification from repo root: $(ROOT_DIR)"
	cd "$(ROOT_DIR)" && bash "$(SCRIPTS_DIR)/verify-host.sh"
	cd "$(ROOT_DIR)" && bash "$(SCRIPTS_DIR)/verify-cluster.sh"