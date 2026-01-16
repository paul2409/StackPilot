Week 1 Runbook – Lab Foundation (Vagrant + Networking + Baseline Checks)

Scope
Provision 3 Ubuntu VMs with static IPs and verify host↔VM and VM↔VM connectivity.

Prereqs (Windows host)

* Vagrant installed: `vagrant --version`
* VirtualBox installed: `VBoxManage --version`
* Run terminal as normal user (Admin usually not needed).
* Enough resources: aim for at least 9GB+ free RAM, 30GB+ free disk for optimal performance.

Repo paths

* `vagrant/Vagrantfile`

Milestone A: Bring up
From repo root:

* `cd vagrant`
* `vagrant up`
* `vagrant status` (expect: all running)

Milestone B: Host connectivity (Windows PowerShell)

* `ping 192.168.56.10 -n 2`
* `ping 192.168.56.11 -n 2`
* `ping 192.168.56.12 -n 2`

Milestone C: SSH + verify inside VMs
Control:

* `vagrant ssh control`
  Inside:
* `hostname` (expect: control)
* `hostname -I` (expect includes: 192.168.56.10)
* `ping -c 2 192.168.56.11`
* `ping -c 2 192.168.56.12`
* `sudo apt-get update`
* `exit`

Worker1:

* `vagrant ssh worker1`
  Inside:
* `hostname` (expect: worker1)
* `hostname -I` (expect includes: 192.168.56.11)
* `ping -c 2 192.168.56.10`
* `sudo apt-get update`
* `exit`

Worker2:

* `vagrant ssh worker2`
  Inside:
* `hostname` (expect: worker2)
* `hostname -I` (expect includes: 192.168.56.12)
* `ping -c 2 192.168.56.10`
* `sudo apt-get update`
* `exit`

Milestone D: Teardown / reset

* Stop: `vagrant halt`
* Destroy: `vagrant destroy -f`

Week 1 acceptance criteria

* `vagrant up` succeeds with no errors
* `vagrant status` shows 3 running VMs
* Windows host can ping all 3 IPs
* Can SSH into all 3 VMs
* Each VM reports correct hostname and correct static IP
* VM-to-VM ping works (control↔workers)
* `sudo apt-get update` succeeds on all VMs
