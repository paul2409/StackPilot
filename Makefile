VAGRANT_DIR := vagrant

.PHONY: up halt destroy status reload ssh-control ssh-worker1 ssh-worker2 provision \
        verify verify-host verify-cluster

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

# If you specifically want reload + provision (heavier but sometimes useful)
reload-provision:
	cd $(VAGRANT_DIR) && vagrant reload --provision

verify:
	@echo "Starting verification..."
	@$(MAKE) verify-host
	@$(MAKE) verify-cluster
	@echo "ALL VERIFICATION PASSED"

verify-host:
	@./scripts/verify_host.sh

verify-cluster:
	@./scripts/verify_cluster.sh
