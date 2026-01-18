# Milestone 01 — 3-Node Lab Foundation

# Overview

This milestone establishes a reproducible 3-VM lab used for all future work.

The lab consists of:

1 control node

2 worker nodes

Host-only networking with static IPs

Hostname-based communication

Verification scripts that define “working”

No application workloads are included in this milestone.

# Node Inventory
Node	Hostname	IP Address	Role
control	control	192.168.56.10	control
worker1	worker1	192.168.56.11	worker
worker2	worker2	192.168.56.12	worker
# Golden Path (Fresh Start)

These steps assume nothing is broken.

# Start the lab

cd vagrant
vagrant up


# Provision all nodes

vagrant provision


# Verify the lab

./scripts/verify_host.sh
./scripts/verify_cluster.sh


# Expected result: all checks pass.

# Stop the lab (end of session)

vagrant halt