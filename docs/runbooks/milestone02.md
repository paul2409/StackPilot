# Milestone 02 — Dockerized Service Contracts, Host-Driven Lifecycle & Failure-First Operations

## Executive Summary

Milestone 02 proves that this system behaves like a real production service.

From the host machine, the system can be:

* started intentionally
* verified truthfully
* failed safely
* recovered without manual intervention

This milestone introduces Dockerized runtime contracts, truthful health and readiness semantics, **explicit TCP-level reachability guarantees**, host-driven lifecycle control, and documented failure drills.

The result is a portable, observable service that fails predictably instead of silently.

---

## What Changed Since Milestone 01

This milestone moves the project from **infrastructure foundations** to **service behavior under real operating conditions**, with explicit host control.

Key changes:

* A real API process replaces lab-only verification
* Docker becomes the enforced runtime
* Configuration, health, readiness, and failure behavior are defined and verified
* A real external dependency (Postgres) is introduced
* The system lifecycle becomes controllable **from the host**, not via manual SSH
* Service reachability is verified at the **TCP transport layer**, not assumed

---

## Purpose

The purpose of this milestone is to establish a **production-behaving service with host-driven lifecycle control**.

The system must be startable, verifiable, and stoppable **from the host machine**, without manual SSH intervention, and must report its state truthfully under both healthy and degraded conditions.

The API itself is intentionally simple. The focus is on **operational correctness**, not features: strict configuration, truthful signals, predictable failure, observable degradation, **verifiable TCP reachability**, and portability across hosts.

---

## What Was Built (Concrete Artifacts)

* A containerized FastAPI service with strict startup contracts
* Truthful `/health`, `/ready`, and `/version` endpoints
* Docker-based runtime with non-root execution
* Docker Compose orchestration with Postgres
* Verified persistence across restarts
* Host-driven lifecycle control (`make up`, `make verify`, `make halt/destroy`)
* Host-driven verification defining system truth
* Runnable, documented failure drills
* Explicit TCP networking validation for service and dependency reachability

---

## Service Behavior Guarantees

* The service refuses to start when required configuration is missing
* `/health` reports **process liveness only**
* `/ready` reports **dependency readiness**
* Dependency failure does not cause crash loops
* The service remains observable during degraded states

### One-Glance Guarantees

| Scenario             | Expected Outcome                     |
| -------------------- | ------------------------------------ |
| Process crash        | `/health` fails                      |
| DB unavailable       | `/health` passes, `/ready` fails     |
| Dependency restored  | `/ready` recovers without restart    |
| Restart service      | Data persists                        |
| TCP port unreachable | Verification fails                   |
| Verification fails   | System must not be considered usable |

---

## Containerization Guarantees

* Pinned base image (no floating tags)
* Deterministic dependency installation
* Non-root execution
* Network-reachable binding (`0.0.0.0`)
* Configuration injected at runtime (not baked into images)

---

## Network & Portability Proof

* The same container image runs on multiple VMs
* The service is reachable across the private VM network
* **TCP connectivity is explicitly validated before HTTP checks**
* No reliance on `localhost` or build-time paths
* Verification can target different service hosts without code changes

---

## TCP Networking Contract (Explicit)

This milestone defines **transport-layer guarantees** for service operation.

Before any HTTP-level check is considered valid:

* The service must be listening on `0.0.0.0:<port>` inside the container
* Docker must publish the port on the VM
* The host must be able to establish a TCP connection to the VM port

Failure at the TCP layer invalidates all higher-level checks.

---

## Dependency & Persistence Proof

* API and database run as separate containers
* Loss of the database causes **readiness failure only**
* Database-dependent endpoints fail predictably
* Data persists across container restarts

---

## Verification as Contract

* Verification is executed **from the host**, not from inside VMs
* Verification scripts define what “working” means
* Verification is authoritative and non-interactive
* A green verification run is the only accepted definition of correctness
* Verification explicitly distinguishes:

  * *alive* vs *ready*
  * *reachable* vs *usable*
  * *TCP reachable* vs *application healthy*

---

## Lifecycle Control Contract

This milestone defines a clear, host-driven lifecycle for the system.

* **`make up`**

  * Brings all VMs online
  * Starts the Docker Compose service stack on the target node

* **`make verify`**

  * Verifies TCP reachability before HTTP semantics
  * Confirms truthful health and readiness behavior
  * Fails loudly when guarantees are violated

* **`make halt` / `make destroy`**

  * Stops services before halting or destroying VMs
  * Prevents hidden running state or data corruption

The system does not require manual SSH for normal operation.

---

## Control Boundary

All lifecycle and verification commands are executed from the host.

VMs are treated as managed infrastructure, not operator workstations.
Manual SSH is reserved for debugging and deliberate failure drills only.

---

## Failure Drills (Deliberate and Repeatable)

Failure is treated as a **first-class condition**, not an exception.

Covered scenarios:

* Incorrect database credentials
* Database unavailability
* Mid-flight dependency loss
* **Service TCP port unreachable**

Each drill documents reproduction, expected behavior, and recovery.

---

## Acceptance Criteria

Milestone 02 is complete only if:

* The system starts from a clean state via the golden path
* Verification passes without manual fixes
* TCP connectivity is proven from host to service
* Health and readiness behave truthfully under failure
* Persistence is proven via restart
* The service runs correctly on more than one host
* At least one failure drill is executed and recovered
* The full lifecycle (up → verify → down) is executable from the host

---

## Reviewer Notes

This milestone prioritizes **operational correctness over feature scope**.

The API is intentionally simple.
The intent is to demonstrate system thinking, networking awareness, and operational discipline — not application complexity.

---

# Operational Runbook — Milestone 02 (Host-Driven)

This runbook documents expected operational behavior.
It is not a tutorial.

All normal operations are executed **from the host** using Make targets.
Direct Docker commands are shown for clarity and debugging only.

---

## Golden Path (Host)

```bash
make up
make verify
make halt
```

---

## TCP Reachability Verification (Authoritative)

From the host:

```bash
nc -zv 192.168.56.10 8000
```

Expected:

* TCP connection succeeds

If this fails, HTTP-level checks are invalid.

---

## Direct Service Verification (Reference)

```bash
curl -i http://192.168.56.10:8000/health
curl -i http://192.168.56.10:8000/ready
curl -i http://192.168.56.10:8000/version
```

### Expected (DB up)

* `/health` → `200`
* `/ready` → `200`

---

## Create Data (Corrected and Verified)

```bash
curl -sS -X POST "http://192.168.56.10:8000/order?symbol=BTC&side=buy&qty=1" | tee /tmp/order.json
```

Expected:

* HTTP `200` or `201`
* JSON containing `order_id`

---

## Verify Data

```bash
curl http://192.168.56.10:8000/orders/<order_id>
```

Expected:

* Order data returned
* Values match original request

---

## Persistence Proof (Restart)

```bash
make halt
make up
curl http://192.168.56.10:8000/orders/<order_id>
```

Expected:

* Order still exists
* No data loss

---

## Failure Drill — Database Down

```bash
cd vagrant
vagrant ssh control
docker compose -f infra/docker-compose.yml stop db
```

From host:

```bash
nc -zv 192.168.56.10 8000
curl -i http://192.168.56.10:8000/health
curl -i http://192.168.56.10:8000/ready
```

Expected:

* TCP reachable
* `/health` → `200`
* `/ready` → `503`

---

## Recover

```bash
docker compose -f infra/docker-compose.yml start db
make verify
```

---

## Stop (Non-Destructive)

```bash
make halt
```

---

### Final Assessment

With explicit TCP verification added, this milestone no longer **assumes networking** — it proves it.

This is now a genuine operational system milestone, not just a Docker exercise.
Violating any of these rules invalidates the milestone.