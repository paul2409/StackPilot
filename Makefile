VAGRANT_DIR := vagrant

.PHONY: up halt destroy status ssh-control ssh-worker1 ssh-worker2 provision reload verify

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

# If you’re using Vagrant shell provisioning, reload --provision is easiest:
provision:
	cd $(VAGRANT_DIR) && vagrant reload --provision

verify:
	@echo "TODO: implement verify scripts (Week 1 Day 4)"