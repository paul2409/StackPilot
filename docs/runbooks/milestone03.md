# Milestone 03 — Operational Hardening & Delivery Discipline

## Purpose

Milestone 03 hardens the system from *“it runs correctly”* into *“it enforces correctness.”*

This milestone does **not** introduce new application features.
It introduces **operational discipline** that prevents stale state, cached luck, and bypassing of the golden path.

By the end of this milestone, the system must prove that:

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

It does **not** change:

* application feature set
* API semantics
* infrastructure topology

---

## Core Guarantees Introduced

Milestone 03 enforces the following guarantees:

1. **Single Golden Path**

   * There is exactly one supported way to start services.
   * All lifecycle actions flow through Make targets and scripts.

2. **Execution Discipline**

   * All operational scripts must execute from `/vagrant` inside the VM.
   * Incorrect execution context causes immediate failure.

3. **Clean-Room Rebuildability**

   * Cached images are not trusted.
   * Rebuilds must occur when images are removed.
   * Rebuild behavior must be observable.

4. **Separation of Concerns**

   * Stopping services is not the same as cleaning state.
   * Cleaning state is not the same as destroying infrastructure.

5. **Verification as Truth**

   * Verification defines correctness.
   * Manual inspection does not override verification failure.

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

All operational scripts enforce the following:

* Execution occurs **inside the VM**
* Repository must be mounted at `/vagrant`
* Scripts refuse to run if executed from:

  * `/home/vagrant`
  * copied folders
  * partial mounts
  * incorrect directories

### Rationale

Running Docker Compose from the wrong directory can silently:

* use the wrong compose file
* load the wrong `.env`
* reference stale source
* produce non-reproducible behavior

Execution context enforcement prevents this class of failure entirely.

---

## Delivery & Build Discipline

Milestone 03 enforces **local build truth**.

### Required behavior

* Application images are built **locally from source**
* No floating image tags (`:latest`)
* No prebuilt images
* No reliance on cached layers to “make it work”

### Enforced outcomes

* `make clean` removes:

  * all compose-managed containers
  * the locally built application image
* `make demo` always rebuilds the image
* Rebuild output is visible in logs
* Verification confirms which image is running

---

## Lifecycle Separation

Lifecycle responsibilities are split deliberately.

### `service-down`

* Stops containers only
* Preserves images
* Preserves volumes
* Used for normal stop/start cycles

### `clean-room`

* Stops containers
* Removes the application image
* Prunes unused build cache
* Preserves volumes (no data loss)

### `destroy`

* Executes clean-room first
* Destroys VMs
* Leaves no running state behind

Mixing these responsibilities is not supported.

---

## Verification Hardening

Verification is authoritative.

Verification must:

* Run from the **host**
* Inspect VM-side state
* Confirm:

  * runtime container state
  * image usage
  * compose wiring
* Never mutate system state

Verification does **not**:

* start services
* fix failures
* make assumptions

If verification fails, the system is not correct.

---

## Reviewer Demo Contract

A reviewer can run:

```bash
make demo-reviewer
```

(or `NODE=worker1 make demo-reviewer`)

This command **always** performs:

1. Clean-room teardown
2. Forced rebuild via the golden path
3. Full verification pass

There is no supported way to bypass this flow.

If this command passes, the system is considered:

* reproducible
* deterministic
* operationally correct

---

## Acceptance Criteria

Milestone 03 is complete only if **all** of the following are true:

* `make clean` removes:

  * all compose-managed containers
  * the locally-built application image
* `make demo` rebuilds the image from source
* Rebuild output is observable
* `make verify` passes after a clean-room rebuild
* Verification reflects real runtime and image state
* Scripts refuse to run outside `/vagrant`
* No manual Docker commands are required
* Guarantees hold on more than one VM

---

## Failure Modes Addressed

This milestone explicitly prevents:

* stale image reuse
* cached “worked once” behavior
* wrong-directory compose execution
* partial repo mounts
* hidden running containers
* unverifiable rebuild claims

---

## Non-Goals

Milestone 03 does **not** attempt to:

* optimize build speed
* introduce CI/CD
* add orchestration beyond Docker Compose
* expand application features

Those concerns are intentionally deferred.

---

## Final Assessment

Milestone 03 transforms the system from *correct-by-intent* to *correct-by-enforcement*.

If any of the guarantees above can be bypassed, the milestone is considered **invalid** and must be corrected before progressing.
