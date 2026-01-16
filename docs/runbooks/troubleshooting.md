Troubleshooting Runbook (StackPilot)

Vagrant can’t find VirtualBox / provider errors
Symptoms

* “No usable default provider could be found”
  Fix
* Confirm VirtualBox installed: `VBoxManage --version`
* Confirm Vagrant sees it: `vagrant up --provider=virtualbox`

Host can’t ping 192.168.56.x
Symptoms

* VMs are running, but ping fails from Windows host
  Checks
* In VirtualBox: Tools → Network → Host-only Networks (ensure one exists)
* In Windows: ensure “VirtualBox Host-Only Network” adapter exists and is enabled
  Fix
* Create/repair host-only network in VirtualBox Host Network Manager
* If subnet conflicts with your machine/network/VPN, change to another range (e.g. 192.168.57.10/11/12) and run:

  * `vagrant reload` (or `vagrant destroy -f && vagrant up`)

SSH times out (`vagrant ssh` fails)
Fix order

* `vagrant reload`
* `vagrant halt && vagrant up`
* If still broken: `vagrant destroy -f && vagrant up`

Hyper-V / WSL2 conflicts (Windows)
Symptoms

* VirtualBox VMs run painfully slow, fail to boot, or VT-x errors
  Fix
* Disable Hyper-V features that conflict (Hyper-V, Virtual Machine Platform, Windows Hypervisor Platform), reboot, retry
* Ensure virtualization is enabled in BIOS/UEFI

Low resources (VMs slow, random failures)
Fix

* Reduce worker sizes in Vagrantfile (e.g., workers 1024MB RAM, 1 CPU)
* Close heavy apps on host

Networking breaks after sleep/VPN
Fix

* Disconnect VPN temporarily and retry ping
* `vagrant reload`
