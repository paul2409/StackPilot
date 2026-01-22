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

## Milestone 01 — Failure Matrix

| ID | Issue| Symptom | Checks | Fix | Verify |
| --------------------------------------------|
| T01 | Host cannot reach VM                 | `verify-host.sh` fails to ping VM IP         | `ping 192.168.56.10`, `vagrant status`                   | Ensure VM is running. Reload VM after network changes. Use correct ping flags for OS (Git Bash vs Linux). | `make verify` |
| T02 | SSH into VM fails                    | `vagrant ssh <node>` fails or hangs          | `vagrant status`, `vagrant ssh-config <node>`            | Start or reload VM. Destroy and rebuild VM if SSH state is corrupted.                                     | `make verify` |
| T03 | Hostname resolution fails            | `verify-cluster.sh` reports hostname error   | `getent hosts control worker1 worker2`, `cat /etc/hosts` | Restore hostname enforcement via provisioning. Never edit `/etc/hosts` manually.                          | `make verify` |
| T04 | Script fails but manual check passes | Verification fails but manual ping/SSH works | Inspect `scripts/verify-*.sh`                            | Fix OS-specific command usage or line endings. Scripts define truth.                                      | `make verify` |

### Milestone 01 Exit Check

Milestone 01 is considered stable only if:

```bash
make destroy
make up
make provision
make verify
```

succeeds **repeatedly**, without manual intervention.

---

# Milestone 02 — Dockerized Service & Runtime Contracts

This section covers **only service-level failures** introduced by Docker, Compose, readiness logic, and persistence.

If an issue is not listed here, it does **not** block Milestone 02 completion.

---

## Milestone 02 — Failure Matrix (Service Layer)

| Area | Symptom | Likely Cause | Checks | Fix | Prevention |
| ----------------------------------------------------------|
| Container  | Container exits immediately          | Missing required env vars    | `docker logs <container>`    | Set required env vars           | Enforce strict startup validation |                           |
| Image      | Code change has no effect            | Image not rebuilt            | `/version`, `docker inspect` | Rebuild image + restart         | Rebuild on every code change      |                           |
| Readiness  | `/ready` returns 200 when DB is down | Stub readiness logic         | Stop DB + `curl /ready`      | Implement DB connectivity check | Enforce readiness contract        |                           |
| Service    | `/health` fails when DB is down      | Health checking dependencies | Stop DB + `curl /health`     | Remove dependency checks        | Health = liveness only            |                           |
| Compose    | App cannot reach DB                  | Wrong `DB_HOST`              | `env                         | grep DB_HOST`                   | Set `DB_HOST=db`                  | Use Compose service names |
| Data       | Data lost after restart              | No named volume              | `docker volume ls`           | Add named volume                | Persistence verification          |                           |
| Volume     | `docker volume rm` fails             | Volume still in use          | `docker ps`                  | Stop containers                 | Stop before removal               |                           |
| Network    | Works in container, not from VM      | Bound to localhost           | `ss -lntp`                   | Bind to `0.0.0.0`               | Explicit bind config              |                           |
| Multi-host | Works on control, fails on worker    | Image not present            | `docker images` on worker    | Build/load image                | Multi-host proof                  |                           |
| Verify     | Manual curl works, verify fails      | Contract violation           | Compare verify output        | Fix invariant                   | Verification defines truth        |                           |

---

## Milestone 02 — Non-Negotiable Runtime Rules

These rules are enforced by verification and are **not optional**:

* Code changes require image rebuild **and** container restart
* `/health` must **never** depend on Postgres
* `/ready` must **always** depend on Postgres
* Restarting containers preserves data
* Removing volumes destroys data
* `depends_on` controls startup order only, **not readiness truth**

---

## Common Pitfall — Stale Image

**Symptom**

* App code changed
* `/ready` or `/version` behavior unchanged

**Cause**

* Container restarted without rebuilding image

**Incorrect Fix**

```bash
docker compose up -d
```

**Correct Fix**

```bash
docker compose down
docker build -t mock-exchange:0.2.0 apps/mock-exchange
docker compose up -d
```

---

## Operational Principles (Global)

These apply to **all milestones**:

* Verification defines truth
* Manual success is not success
* Restarting containers ≠ rebuilding images
* Persistence must be proven, not assumed
* Failures are documented, not hidden

---

## Final Assessment

This runbook is intentionally **minimal and authoritative**.

It does not explain *how to debug*.
It documents **what breaks**, **why**, and **how to restore invariants**.

If verification passes and no listed failure is active, the system is considered operational.

---


