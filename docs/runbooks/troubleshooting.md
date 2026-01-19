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



## Milestone 2 — Docker & Service Troubleshooting Matrix (Week 2)

This table covers the full failure surface introduced in Milestone 2:
Docker runtime, containers, Compose, service configuration, networking,
persistence, and policy enforcement.

Use this as the primary reference before rebuilding or changing code.

| Area | Symptom | Likely Cause | Primary Checks | Fix | Prevention |
|-----|--------|--------------|----------------|-----|------------|
| Docker runtime | `docker ps` fails or daemon not reachable | Docker not running or service failed | `systemctl status docker` | `systemctl start docker` | Enable Docker on boot |
| Docker runtime | `permission denied` on docker socket | User not in docker group | `groups`, `docker ps` | Re-SSH after `usermod -aG docker` | Provision user/group correctly |
| Container | Container not running | Startup failure | `docker ps -a`, `docker logs` | Fix config/startup error | Enforce config checks |
| Container | Container exits immediately | Missing env vars or bad entrypoint | `docker logs`, `docker inspect` | Fix env vars / CMD | Required env validation |
| Container | Wrong image version running | Stale build or wrong tag | `docker inspect` | Rebuild with correct tag | Version endpoint + tags |
| Networking | Port not listening | App crash or wrong port binding | `ss -lntp`, `docker inspect` | Fix bind address / mapping | Standardize ports |
| Networking | Works locally, fails remotely | Bound to localhost only | `ss -lntp` | Bind to `0.0.0.0` | Explicit bind config |
| Networking | Worker cannot reach control | Docker or VM networking issue | `curl`, `ping`, `ip r` | Fix network / firewall | Verify cross-VM access |
| Service | `/health` fails | Process not running | `docker logs`, `docker ps` | Fix crash | Health = liveness only |
| Service | `/ready` fails but `/health` ok | Dependency unavailable (DB) | `docker logs`, DB check | Restore dependency | Separate health/readiness |
| Compose | Services not starting | Compose config error | `docker compose config`, logs | Fix compose file | Validate compose |
| Compose | Port exposed but unreachable | Wrong port mapping | `docker compose ps`, `ss -lntp` | Fix ports | Document ports |
| Compose | Service name not resolvable | Wrong network or service name | `docker network inspect` | Fix network/service name | Single user-defined network |
| Data | Data lost after restart | No volume or wrong mount | `docker volume ls`, inspect | Add named volume | Persistence verification |
| Data | App starts but DB empty | Schema not applied | App logs, DB inspect | Apply schema | Startup checks |
| Config | Service refuses to start | Missing required env var | Startup logs | Provide env var | Strict config contract |
| Config | Service starts with bad config | No validation | Logs | Add validation | Fail fast on bad config |
| Policy | Image uses `:latest` | Floating tag | `grep latest` | Pin tag | Policy gate |
| Policy | Container runs as root | Missing USER | `docker inspect` | Add USER | Policy gate |
| Policy | Missing healthcheck | Compose/Dockerfile omission | Inspect config | Add healthcheck | Policy gate |
| Multi-host | App runs on control only | Hardcoded host assumptions | Run on worker1 | Fix assumptions | Multi-host proof |
| Verify | `make verify` fails | Known failure detected | Read FAIL output | Fix exact cause | Trust verify |
| Verify | Manual curl works, verify fails | Partial system failure | Compare checks | Fix invariant | Verify defines truth | 

Rules introduced in mock-exchange service:

- Missing required env vars → service must refuse to start
- `/health` = process alive only
- `/ready` = service ready to accept traffic
- `/version` exposes runtime/build metadata

Required env vars:
- SERVICE_NAME
- ENV
- LOG_LEVEL
- VERSION

Example startup failure:
```bash
unset VERSION
uvicorn app:app --host 0.0.0.0 --port 8000
# Fails with error: "VERSION env var is required"
```