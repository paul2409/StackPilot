# Milestone 03 — Operational Hardening & Delivery Discipline

## Purpose

Milestone 03 hardens the system from **“it runs correctly”** into **“it enforces correctness.”**

This milestone introduces **operational discipline**, not new application features.
Its purpose is to eliminate stale state, cached luck, and unsupported execution paths.

By the end of this milestone, the system must **prove**, through executable behavior, that:

* rebuilds are mandatory and observable
* execution context is enforced
* verification reflects real runtime state
* recovery does not require manual Docker or SSH intervention
* the same guarantees hold across multiple VMs

---

## Scope

This milestone applies to:

* service lifecycle control
* build and delivery discipline
* execution context enforcement
* verification hardening
* reviewer-grade reproducibility

This milestone does **not** change:

* application features
* API semantics
* infrastructure topology

---

## Core Guarantees Introduced

Milestone 03 introduces and enforces the following guarantees.

### 1. Single Golden Path

* There is exactly one supported way to operate services.
* All lifecycle actions flow through Make targets and controlled scripts.
* Direct Docker, Docker Compose, or SSH-driven workflows are unsupported.

---

### 2. Execution Discipline

* All operational scripts must execute **inside the VM**.
* The repository must be mounted at `/vagrant`.
* Incorrect execution context causes **immediate failure**.

There is no supported override.

---

### 3. Clean-Room Rebuildability

* Cached images are not trusted.
* Application images must rebuild when removed.
* Rebuild behavior must be observable in logs and verifiable at runtime.

---

### 4. Separation of Concerns

* Stopping services is not equivalent to cleaning state.
* Cleaning state is not equivalent to destroying infrastructure.
* Each action has a distinct, enforced responsibility.

---

### 5. Verification as Truth

* Verification defines correctness.
* Manual inspection does not override verification failure.
* If verification fails, the system is incorrect by definition.

---

## Canonical Operational Interface

These are the **only supported commands** for Milestone 03.

### Service lifecycle

```bash
make up
make demo
make verify
make down
```

### Clean-room / reviewer flow

```bash
make clean
make demo-reviewer
make destroy
```

Rules:

* If `make verify` fails, the system is not considered working.
* Manual Docker commands do not override verification.
* SSH is not required for normal operation.

---

## Execution Context Contract

All operational scripts enforce the following constraints:

* Execution occurs **inside the VM**
* Repository must be mounted at `/vagrant`
* Scripts refuse to run if executed from:

  * `/home/vagrant`
  * copied repositories
  * partial mounts
  * incorrect working directories

### Rationale

Running Docker Compose from an incorrect directory can silently:

* select the wrong compose file
* load the wrong environment variables
* reference stale source code
* produce non-reproducible behavior

Execution context enforcement eliminates this entire failure class.

---

## Delivery & Build Discipline

Milestone 03 enforces **local build truth**.

### Required behavior

* Application images are built **locally from source**
* No floating tags (e.g. `:latest`)
* No prebuilt images
* No reliance on cached layers to “make things work”

### Enforced outcomes

* `make clean` removes:

  * all compose-managed containers
  * the locally built application image
* `make demo` forces an image rebuild
* Rebuild output is visible in logs
* Verification confirms which image is running

---

## Lifecycle Separation

Lifecycle responsibilities are deliberately separated.

### `make down`

* Stops containers only
* Preserves images
* Preserves volumes
* Used for normal stop/start cycles

### `make clean`

* Stops containers
* Removes the application image
* Prunes unused build cache
* Preserves volumes (no data loss)

### `make destroy`

* Executes `make clean`
* Destroys all VMs
* Leaves no running or hidden state behind

Mixing these responsibilities is unsupported.

---

## Verification Hardening

Verification is **authoritative**.

Verification must:

* Run from the **host**
* Inspect VM-side runtime state
* Confirm:

  * container status
  * image identity
  * compose wiring and port exposure
* Never mutate system state

Verification does **not**:

* start services
* fix failures
* assume correctness

If verification fails, the system is incorrect.

---

## Phase 2 — Failure & Recovery Enforcement

Milestone 03 includes a mandatory **failure and recovery drill** proving honest degradation and automatic recovery.

### Failure Scenario: Database Unavailable

A deliberate mid-flight dependency failure is introduced.

When the database becomes unavailable while the API is running, the system must prove:

* The API process remains reachable at the TCP layer
* `/health` continues to return `200`
* `/ready` returns a non-`200` status
* Host-side verification fails during the outage
* Recovery occurs automatically when the dependency returns
* No API restart is required for recovery

---

### Drill Script (Authoritative)

The failure and recovery sequence is encoded in:

```bash
scripts/drills/db-ready.sh
```

This script:

1. Verifies a clean baseline
2. Stops **only** the database container
3. Proves TCP reachability from the host
4. Asserts:

   * `/health` = 200
   * `/ready` ≠ 200
5. Confirms verification failure during the outage
6. Restarts the database container
7. Proves readiness recovers without restarting the API
8. Confirms verification passes again

---

### Tooling Portability

To avoid reviewer friction, the drill:

* Prefers raw TCP checks (`nc`)
* Falls back to `/dev/tcp` or short-timeout `curl`
* Requires no additional tooling installation

The drill remains **host-driven and authoritative**.

---

## Reviewer Demo Contract

A reviewer can run:

```bash
make demo-reviewer
```

(or `NODE=worker1 make demo-reviewer`)

This command always performs:

1. Clean-room teardown
2. Forced rebuild via the golden path
3. Full verification pass

There is no supported bypass.

If this command passes, the system is considered:

* reproducible
* deterministic
* operationally correct

---

## Acceptance Criteria

Milestone 03 is complete only if **all** of the following hold:

* `make clean` removes containers and application images
* `make demo` rebuilds the image from source
* Rebuild output is observable
* `make verify` passes after a clean-room rebuild
* Verification reflects real runtime and image state
* Scripts refuse to run outside `/vagrant`
* No manual Docker commands are required
* Failure drill proves honest degradation and recovery
* Guarantees hold on more than one VM

---

## Failure Modes Addressed

This milestone explicitly prevents:

* stale image reuse
* cached “worked once” behavior
* wrong-directory compose execution
* partial repository mounts
* hidden running containers
* unverifiable rebuild claims
* silent dependency failures

---

## Non-Goals

Milestone 03 does **not** attempt to:

* optimize build speed
* introduce CI/CD
* add orchestration beyond Docker Compose
* expand application features

These concerns are intentionally deferred.

---

## Final Assessment

Milestone 03 transforms the system from **correct-by-intent** to **correct-by-enforcement**.

Failure behavior is no longer assumed.
Recovery is no longer manual.
Verification is no longer optional.

If any guarantee above can be bypassed, the milestone is **invalid** and must be corrected before progressing.

---
