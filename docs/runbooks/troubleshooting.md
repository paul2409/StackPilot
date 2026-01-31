# Troubleshooting Runbook — StackPilot (Authoritative)

This runbook records **verified, reproducible failures** encountered during the StackPilot build and their **validated fixes**.

Entries are appended per milestone.  
If an issue is not listed here, it is **not milestone-blocking**.

Verification scripts are the source of truth.  
Manual success does **not** override verification failure.

---

## How to Use This Runbook

1. Identify the active milestone  
2. Match the symptom exactly  
3. Follow checks **before** applying fixes  
4. Re-run verification after every fix  

If verification still fails, the issue is not yet understood and must be investigated, not worked around.

---

# Milestone 01 — Lab Foundation (Infrastructure Truth)

This section covers **infrastructure-level failures only**.  
If any issue here exists, **Milestone 02+ work is invalid**.

---

## Milestone 01 — Failure Matrix (Mapped)

| ID  | Guarantee | Issue                          | Symptom                                   | Checks                                             | Fix                                                                 | Verify      |
| --- | --------- | ------------------------------ | ----------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------- | ----------- |
| T01 | G-01-01   | Host cannot reach VM           | `verify-host.sh` fails to ping VM IP      | `ping 192.168.56.10`, `vagrant status`             | Ensure VM is running. Reload VM after network changes. Use correct ping flags for OS (Git Bash vs Linux). | `make verify` |
| T02 | G-01-02   | SSH into VM fails              | `vagrant ssh <node>` fails or hangs       | `vagrant status`, `vagrant ssh-config <node>`      | Start or reload VM. Destroy and rebuild VM if SSH state is corrupted. | `make verify` |
| T03 | G-01-03   | Hostname resolution fails      | `verify-cluster.sh` reports hostname error| `getent hosts control worker1 worker2`, `/etc/hosts` | Restore hostname enforcement via provisioning. Never edit `/etc/hosts` manually. | `make verify` |
| T04 | G-01-04   | Script fails but manual passes | Verification fails but manual ping works  | Inspect `scripts/verify-*.sh`                      | Fix OS-specific command usage or line endings. Scripts define truth. | `make verify` |

### Milestone 01 Exit Check

```bash
make destroy
make up
make provision
make verify


⸻

Milestone 02 — Dockerized Service & Runtime Contracts

This section covers only service-level failures introduced by Docker, Compose, readiness logic, and persistence.

⸻

Milestone 02 — Failure Matrix (Service Layer, Mapped)

## Milestone 02 — Failure Matrix (Mapped)

| ID | Guarantee | Issue | Symptom | Checks | Fix | Verify |
| -- | --------- | ----- | ------- | ------ | --- | ------ |
| T02-01 | G-02-01 | Container exits immediately | Container stops on startup | `docker logs <container>` | Set required env vars | `make verify` |
| T02-02 | G-02-05 | Image rebuild skipped | Code change has no effect | `/version`, `docker inspect` | Rebuild image + restart | `make verify` |
| T02-03 | G-02-02 | Readiness lies | `/ready` returns 200 when DB is down | Stop DB + `curl /ready` | Implement DB connectivity check | `make verify` |
| T02-04 | G-02-01 | Health coupled to DB | `/health` fails when DB is down | Stop DB + `curl /health` | Remove DB dependency from health | `make verify` |
| T02-05 | G-02-03 | Compose networking broken | App cannot reach DB | `env | grep DB_HOST` | Set `DB_HOST=db` | `make verify` |
| T02-06 | G-02-04 | No persistence | Data lost after restart | `docker volume ls` | Add named volume | `make verify` |
| T02-07 | G-02-04 | Volume removal fails | `docker volume rm` errors | `docker ps` | Stop containers before removal | `make verify` |
| T02-08 | G-02-03 | Wrong bind address | Works in container, not VM | `ss -lntp` | Bind to `0.0.0.0` | `make verify` |
| T02-09 | G-02-05 | Multi-node inconsistency | Works on control, fails on worker | `docker images` on worker | Build/load image on worker | `make verify` |
| T02-10 | G-01-04 | Manual ≠ verified | Manual curl works, verify fails | Compare verify output | Fix invariant violation | `make verify` |


⸻

Milestone 03 — Operational Hardening & Delivery Discipline

Milestone 03 — Failure Matrix (Hardening Layer, Mapped)

## Milestone 03 — Failure Matrix (Mapped)

| ID | Guarantee | Issue | Symptom | Checks | Fix | Verify |
| -- | --------- | ----- | ------- | ------ | --- | ------ |
| T03-01 | G-03-01 | Wrong execution context | Script exits immediately | `pwd`, `mount | grep vagrant` | Run from `/vagrant` | `make verify` |
| T03-02 | G-03-01 | Wrong compose/env | Script runs against wrong config | `pwd`, `ls docker-compose.yml` | Ensure repo mounted at `/vagrant` | `make verify` |
| T03-03 | G-03-02 | Cached build | Code change has no effect | `/version`, `docker inspect` | `make clean && make demo` | `make verify` |
| T03-04 | G-03-02 | Build not enforced | `make demo` skips rebuild | Inspect build logs | Fix Makefile rebuild logic | `make verify` |
| T03-05 | G-03-02 | Dirty clean-room | App image remains after clean | `docker images | grep app` | Remove locally built image | `make verify` |
| T03-06 | G-03-02 | Containers still running | Containers survive clean | `docker ps` | Stop compose-managed containers | `make verify` |
| T03-07 | G-03-04 | Verification overridden | Manual success, verify fails | Review verify output | Fix invariant | `make verify` |
| T03-08 | G-03-08 | Verify mutates state | Verification changes runtime | Review verify scripts | Remove mutations | `make verify` |
| T03-09 | G-03-03 | Lifecycle violated | `make down` removes data | Images/volumes | Restore lifecycle separation | `make verify` |
| T03-10 | G-03-03 | Destroy incomplete | `make destroy` skips clean | Review destroy flow | Run clean before destroy | `make verify` |
| T03-11 | G-03-01 | Node-specific behavior | Control works, worker fails | `NODE=worker1 make demo` | Remove node assumptions | `make verify` |
| T03-12 | G-03-07 | Health dishonest | `/health` fails when DB down | Stop DB + curl | Remove DB check from health | `make verify` |
| T03-13 | G-03-07 | Readiness dishonest | `/ready` still 200 when DB down | Stop DB + curl | Fix readiness logic | `make verify` |
| T03-14 | G-03-07 | No recovery | Readiness never recovers | Restart DB only | Fix retry logic | `make verify` |


⸻

Milestone 04 — CI Authority & Terraform Structure Enforcement

Milestone 04 — Failure Matrix (CI + Terraform Layer)

## Milestone 04 — Failure Matrix (Mapped)

| ID | Guarantee | Issue | Symptom | Checks | Fix | Verify |
| -- | --------- | ----- | ------- | ------ | --- | ------ |
| T04-01 | G-04-01 | CI not authoritative | PR merges despite failure | Branch protection rules | Require CI to pass | GitHub PR |
| T04-02 | G-04-01 | Local ≠ CI | Local pass, CI fail | Compare logs | Fix env assumptions | CI run |
| T04-03 | G-04-02 | No CI logs | CI fails silently | Check artifacts | Pipe output via `tee` | CI run |
| T04-04 | G-04-04 | Terraform missing | `terraform` not found | CI logs | Install Terraform in CI | CI run |
| T04-05 | G-04-04 | Version mismatch | Unsupported core version | `versions.tf` | Align pinned versions | CI run |
| T04-06 | G-04-05 | Formatting failure | `fmt -check` fails | fmt logs | `make tf-fmt` + commit | `make check-terraform` |
| T04-07 | G-04-05 | Validation failure | `terraform validate` fails | validate logs | Fix config | `make check-terraform` |
| T04-08 | G-04-04 | Drift | Works locally, fails in CI | Version compare | Remove implicit assumptions | CI run |
| T04-09 | G-04-05 | CI mutates infra | apply/destroy executed | Workflow audit | Remove permanently | CI run |
| T04-10 | G-04-03 | Makefile bypass | Raw terraform used | Repo audit | Enforce Makefile usage | `make check-terraform` |
| T04-11 | G-04-01 | CI scope leak | CI runs runtime checks | CI logs | Restrict CI scope | CI run |
| T04-12 | G-04-01 | False confidence | Manual plan works, CI fails | CI logs | Fix until CI passes | CI run |

---
