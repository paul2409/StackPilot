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

| ID | Guarantee | Issue| Symptom | Checks | Fix | Verify |
| –– | ——— | ––––––––––––––––––––––|
| T01 | G-01-01 | Host cannot reach VM | verify-host.sh fails to ping VM IP | ping 192.168.56.10, vagrant status | Ensure VM is running. Reload VM after network changes. Use correct ping flags for OS (Git Bash vs Linux). | make verify |
| T02 | G-01-02 | SSH into VM fails | vagrant ssh <node> fails or hangs | vagrant status, vagrant ssh-config <node> | Start or reload VM. Destroy and rebuild VM if SSH state is corrupted. | make verify |
| T03 | G-01-03 | Hostname resolution fails | verify-cluster.sh reports hostname error | getent hosts control worker1 worker2, cat /etc/hosts | Restore hostname enforcement via provisioning. Never edit /etc/hosts manually. | make verify |
| T04 | G-01-04 | Script fails but manual check passes | Verification fails but manual ping/SSH works | Inspect scripts/verify-*.sh | Fix OS-specific command usage or line endings. Scripts define truth. | make verify |
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


## Milestone 02 — Failure Matrix (Service Layer, Mapped)

| Area | Guarantee | Symptom | Likely Cause | Checks | Fix | Prevention |
| –– | ——— | –––––––––––––––––––––––––––––|
| Container | G-02-01 | Container exits immediately | Missing required env vars | docker logs <container> | Set required env vars | Enforce strict startup validation |
| Image | G-02-05 | Code change has no effect | Image not rebuilt | /version, docker inspect | Rebuild image + restart | Rebuild on every code change |
| Readiness | G-02-02 | /ready returns 200 when DB is down | Stub readiness logic | Stop DB + curl /ready | Implement DB connectivity check | Enforce readiness contract |
| Service | G-02-01 | /health fails when DB is down | Health checking dependencies | Stop DB + curl /health | Remove dependency checks | Health = liveness only |
| Compose | G-02-03 | App cannot reach DB | Wrong DB_HOST | env | grep DB_HOST | Set DB_HOST=db | Use Compose service names |
| Data | G-02-04 | Data lost after restart | No named volume | docker volume ls | Add named volume | Persistence verification |
| Volume | G-02-04 | docker volume rm fails | Volume still in use | docker ps | Stop containers | Stop before removal |
| Network | G-02-03 | Works in container, not from VM | Bound to localhost | ss -lntp | Bind to 0.0.0.0 | Explicit bind config |
| Multi-host | G-02-05 | Works on control, fails on worker | Image not present | docker images on worker | Build/load image | Multi-host proof |
| Verify | G-01-04 | Manual curl works, verify fails | Contract violation | Compare verify output | Fix invariant | Verification defines truth |

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


# Milestone 03 — Operational Hardening & Delivery Discipline

This section covers **delivery, execution-context, rebuild, and verification failures** introduced by Milestone 03.

If any issue here exists, **Milestone 04+ work is invalid**.

---

Milestone 03 — Failure Matrix (Hardening Layer, Mapped)

| ID | Guarantee | Area | Symptom | Checks | Fix | Verify |
| –– | ——— | —————– | —————————————–– |
| T03-01 | G-03-01 | Execution Context | Script exits immediately with context error | pwd, mount | grep vagrant | Run script inside VM from /vagrant. Do not copy repo or run from $HOME. | make verify |
| T03-02 | G-03-01 | Execution Context | Script runs but uses wrong compose/env | pwd, ls docker-compose.yml | Ensure repo is mounted at /vagrant and invoked from there. | make verify |
| T03-03 | G-03-02 | Build Discipline | Code changes have no effect | /version,docker inspect | Run make clean then make demo. Do not restart containers only. | make verify |
| T03-04 | G-03-02 | Build Discipline | make demo does not rebuild image | Inspect build logs | Fix Makefile or script so image is rebuilt when missing. Cached success is invalid. | make verify |
| T03-05 | G-03-02 | Clean-room | make clean leaves app image behind | docker images | grep <app> | Update clean logic to remove locally built image explicitly. | make verify |
| T03-06 | G-03-02 | Clean-room | Containers still running after clean | docker ps | Stop compose-managed containers explicitly before rebuild. | make verify |
| T03-07 | G-03-04 | Verification | Manual curl works, verify fails | Review verify output | Fix invariant violation. Manual success does not override verification. | make verify |
| T03-08 | G-03-08 | Verification | Verify mutates system state | Review verify scripts | Remove any start/stop/build logic from verification scripts. | make verify |
| T03-09 | G-03-03 | Lifecycle | make down removes images or volumes | docker images, docker volume ls | Restore lifecycle separation. down must stop only. | make verify |
| T03-10 | G-03-03 | Lifecycle | make destroy skips clean-room | Review destroy script | Ensure make clean runs before VM destruction. | make verify |
| T03-11 | G-03-01 | Multi-VM | Works on control, fails on worker | NODE=worker1 make demo | Ensure same golden path works on all nodes. Fix node assumptions. | NODE=worker1 make verify |
| T03-12 | G-03-07 | Failure Drill | DB stopped but /health fails | Stop DB + curl /health | Remove dependency checks from health endpoint. | make verify |
| T03-13 | G-03-07 | Failure Drill | DB stopped but /ready still 200 | Stop DB + curl /ready | Fix readiness logic to reflect dependency truthfully. | make verify |
| T03-14 | G-03-07 | Recovery | DB restored but readiness never recovers | Restart DB only | Fix connection retry logic. API restart is not allowed. | make verify |


---

## Milestone 03 — Non-Negotiable Operational Rules

These rules are enforced and are **not optional**:

* All operational scripts must run from `/vagrant`
* Restarting containers ≠ rebuilding images
* `make down` ≠ `make clean` ≠ `make destroy`
* Verification does not fix failures
* Manual Docker or SSH intervention invalidates the guarantee
* Recovery must occur **without restarting the API**

---

## Common Pitfall — Cached Success

**Symptom**

* System “worked earlier”
* `make demo` succeeds
* `make verify` fails after clean-room

**Cause**

* Image rebuild was skipped
* Cached state masked a broken delivery path

**Incorrect Fix**

```bash
docker compose up -d
```

**Correct Fix**

```bash
make clean
make demo
make verify
```

If this sequence fails, the system is incorrect.

---

## Milestone 03 Exit Check

Milestone 03 is considered stable only if **all** of the following succeed repeatedly:

```bash
make demo-reviewer
NODE=worker1 make demo-reviewer
```

No manual steps.
No cached state.
No SSH intervention.

---

## Final Assessment

This section documents **hardening-layer failures only**.

If:

* verification passes,
* no listed failure is active,
* and reviewer demo flows succeed,

then Milestone 03 guarantees are considered **enforced and proven**.

---



# Milestone 04 — CI Authority & Terraform Structure Enforcement

This section covers **CI enforcement failures and Terraform structure discipline issues** introduced in Milestone 04.

If any issue here exists, **Milestone 05+ work is invalid**.

Milestone 04 failures are **policy and determinism failures**, not runtime failures.

---

Milestone 04 — Failure Matrix (CI + Terraform Layer)

| ID | Guarantee | Area| Symptom | Checks| Fix | Verify|
| —— | ——— | –––––––––– | —————————————— | –––––––––––––––– | ————————————————— |
| T04-01 | G-04-01 | CI Authority| Pull request merges despite failing checks | Branch protection rules| Require hosted CI job to pass before merge| Re-open PR,confirm merge blocked |
| T04-02 | G-04-01 | CI Authority| CI passes locally but fails on GitHub| Compare local vs CI logs| Fix environment assumptions. CI defines truth.| GitHub Actions run|
| T04-03 | G-04-02 | CI Logging | CI fails but no logs available | Check ci/logs/ artifacts | Ensure all CI steps pipe output via tee| Re-run CI|
| T04-04 | G-04-04 | Terraform CLI| terraform: command not found in CI| CI logs| Install Terraform explicitly in workflow| Re-run CI|
| T04-05 | G-04-04 | Terraform Versioning | Unsupported Terraform Core version| versions.tf, CI logs| Align pinned version with installed Terraform| Re-run CI|
| T04-06 | G-04-05 | Terraform Formatting | terraform fmt -check fails| ci/logs/terraform-fmt.txt|Run make tf-fmt locally and commit changes| make check-terraform|
| T04-07 | G-04-05 | Terraform Validation | terraform validate fails| ci/logs/terraform-validate.txt | Fix invalid variables/providers/modules| make check-terraform |
| T04-08 | G-04-04 | Terraform Drift | Works locally, fails in CI | Compare terraform version| Remove implicit provider/core assumptions | Re-run CI |
| T04-09 | G-04-05 | Terraform Discipline | CI attempts apply/destroy | CI logs, workflow | Remove apply/destroy from CI permanently| CI passes |
| T04-10 | G-04-03 | Makefile Bypass| Terraform run outside Makefile | Repo audit| Remove raw CLI usage. Makefile is authoritative | make check-terraform |
| T04-11 | G-04-01 | CI Scope| CI attempts runtime verification| CI logs| Restrict CI to repo + Terraform gates only|CI passes|
| T04-12 | G-04-01 | False Confidence| Manual Terraform plan works, CI fails| CI logs| Fix code until CI passes. Manual success irrelevant | CI passes|

---

## Milestone 04 — Non-Negotiable CI Rules

These rules are enforced and **not optional**:

* CI is the merge authority
* If CI fails, the change is invalid
* Terraform versions must be pinned
* Terraform formatting must be enforced automatically
* CI must never mutate infrastructure
* No apply or destroy in CI
* Makefile is the only supported interface
* Logs must always be inspectable

Violating any rule invalidates Milestone 04.

---

## Common Pitfall — Local Terraform Success

**Symptom**

* `terraform plan` works locally
* CI fails on `fmt` or `validate`

**Cause**

* Local environment differs from CI
* Formatting or version drift

**Incorrect Fix**

```bash
Ignore CI and merge anyway
```

**Correct Fix**

```bash
make tf-fmt
make check-terraform
git commit -am "Fix Terraform formatting/validation"
```

CI defines truth.

---

## Common Pitfall — CI Owns Too Much

**Symptom**

* CI tries to start services
* CI touches VMs
* CI runs Docker runtime checks

**Cause**

* CI scope leak from earlier milestones

**Fix**

* Remove runtime steps from CI
* Restrict CI to repo + Terraform structure enforcement

---

## Milestone 04 Exit Check

Milestone 04 is considered stable only if **all** of the following are true:

```bash
# On every pull request
CI runs automatically
CI fails on bad Terraform
CI blocks merge on failure
CI uploads logs on failure
```

And locally:

```bash
make check-terraform
```

passes without modification.

---

## Final Assessment

Milestone 04 establishes **enforcement, not execution**.

If:

* CI blocks bad changes,
* Terraform structure is pinned and validated,
* logs are always available,
* and no runtime actions occur in CI,

then Milestone 04 guarantees are considered **enforced and complete**.

---


