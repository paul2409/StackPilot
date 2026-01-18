# Troubleshooting Runbook

This file records verified fixes discovered during the StackPilot build.  
Entries are appended per milestone.

## Milestone 01 — Lab Foundation (Week 1)

| **Issue** | **Symptom** | **Checks** | **Fix** | **Verify** |

| --- | --- | --- | --- | --- |
| **T01: Host cannot reach VM** | `verify_host.sh` fails to ping VM IP | `ping 192.168.56.10`, `vagrant status` | Ensure VM is running. Reload VM after network changes. Use correct ping flags for OS (Git Bash vs Linux). | `./scripts/verify_host.sh` |

| **T02: SSH into VM fails** | `vagrant ssh <node>` fails or hangs | `vagrant status`, `vagrant ssh-config <node>` | Start or reload VM. Destroy and rebuild VM if SSH state is corrupted. | `vagrant ssh <node>` |

| **T03: Hostname resolution fails** | `verify_cluster.sh` reports hostname error | `getent hosts control worker1 worker2`, `cat /etc/hosts` | Restore missing `/etc/hosts` entries. Re-run provisioning if needed. | `./scripts/verify_cluster.sh` |

| **T04: Script fails, manual works** | Script reports FAIL but manual check passes | `cat scripts/verify_*.sh` | Fix OS-specific command usage. Normalize line endings if required. | `./scripts/verify_host.sh`, `./scripts/verify_cluster.sh` |

**Milestone 01 Exit Criteria:**  
Lab rebuilds cleanly, provisioning is re-runnable, and verification scripts reliably detect failures.


