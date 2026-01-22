## Milestone 02 — Dockerized Service Contracts, Host-Driven Lifecycle & Failure-First Operations

## Executive Summary

Milestone 02 proves that this system behaves like a real production service.

From the host machine, the system can be:

* started intentionally,
* verified truthfully,
* failed safely,
* and recovered without manual intervention.

This milestone introduces Dockerized runtime contracts, truthful health and readiness semantics, host-driven lifecycle control, and documented failure drills.
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

---

## Purpose

The purpose of this milestone is to establish a **production-behaving service with host-driven lifecycle control**.

The system must be startable, verifiable, and stoppable **from the host machine**, without manual SSH intervention, and must report its state truthfully under both healthy and degraded conditions.

The API itself is intentionally simple. The focus is on **operational correctness**, not features: strict configuration, truthful signals, predictable failure, observable degradation, and portability across hosts.

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

---

## Service Behavior Guarantees

* The service refuses to start when required configuration is missing
* `/health` reports **process liveness only**
* `/ready` reports **dependency readiness**
* Dependency failure does not cause crash loops
* The service remains observable during degraded states

### One-Glance Guarantees

| Scenario            | Expected Outcome                     |
| ------------------- | ------------------------------------ |
| Process crash       | `/health` fails                      |
| DB unavailable      | `/health` passes, `/ready` fails     |
| Dependency restored | `/ready` recovers without restart    |
| Restart service     | Data persists                        |
| Verification fails  | System must not be considered usable |

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
* No reliance on `localhost` or build-time paths
* Verification can target different service hosts without code changes

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

---

## Lifecycle Control Contract

This milestone defines a clear, host-driven lifecycle for the system.

* **`make up`**

  * Brings all VMs online
  * Starts the Docker Compose service stack on the control node

* **`make verify`**

  * Verifies system state from the host perspective
  * Confirms truthful health and readiness semantics
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

Each drill documents reproduction, expected behavior, and recovery.

---

## Acceptance Criteria

Milestone 02 is complete only if:

* The system starts from a clean state via the golden path
* Verification passes without manual fixes
* Health and readiness behave truthfully under failure
* Persistence is proven via restart
* The service runs correctly on more than one host
* At least one failure drill is executed and recovered
* The full lifecycle (up → verify → down) is executable from the host

---

## Reviewer Notes

This milestone prioritizes **operational correctness over feature scope**.

The API is intentionally simple. The intent is to demonstrate system thinking and operational discipline, not application complexity.

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

## Direct Service Verification (Reference)

From the host (targeting the control node):

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

Earlier attempts failed due to payload mismatch.
The correct request format is:

```bash
curl -sS -X POST "http://localhost:8000/order?symbol=BTC&side=buy&qty=1" | tee /tmp/order.json
```

### Expected Response

* HTTP `200` or `201`
* JSON response containing a generated `order_id`

---

## Verify Data

```bash
curl http://192.168.56.10:8000/order/<order_id>
```

Expected:

* Order data is returned
* Values match the original request

---

## Persistence Proof (Restart)

```bash
make halt
make up
```

Then re-run:

```bash
curl http://192.168.56.10:8000/order/<order_id>
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
curl -i http://192.168.56.10:8000/health
curl -i http://192.168.56.10:8000/ready
```

### Expected Behavior (DB Down)

* `/health` → `200` (process alive)
* `/ready` → `503` (dependency unavailable)
* Service does not crash or restart
* Verification fails intentionally when readiness is expected to be up

---

## Recover

```bash
docker compose -f infra/docker-compose.yml start db
```

From host:

```bash
make verify
```

### Expected Recovery

* `/ready` returns `200`
* No service restart required
* Verification passes without modification

---

## Stop (Non-Destructive)

```bash
make halt
```

---

### Final Assessment

With this milestone, the project transitions from **setup** to **system**.
This is no longer a Docker exercise — it is a controlled, verifiable service with explicit operational guarantees.