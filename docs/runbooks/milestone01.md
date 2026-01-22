## Milestone 01 — Lab Foundation, Deterministic Identity & Verification Contracts

## Executive Summary

Milestone 01 establishes the **authoritative lab foundation** for StackPilot.

It proves that a deterministic, reproducible 3-VM environment can be created, verified, destroyed, and rebuilt **without drift**. All later milestones depend on the guarantees defined here.

If this milestone is unstable, **no higher-level work is valid**.

---

## Purpose

The purpose of this milestone is to establish a **reliable, repeatable infrastructure substrate** on which all future system behavior depends.

Milestone 01 does **not** run applications.
It defines **identity, connectivity, verification, and failure boundaries**.

This milestone answers one question only:

> “Do I have a trustworthy lab environment?”

---

## Authoritative Lab Topology

This topology is **fixed and enforced**.
Any deviation is a failure.

| Node    | Hostname | IP            | Role         |
| ------- | -------- | ------------- | ------------ |
| control | control  | 192.168.56.10 | Control node |
| worker1 | worker1  | 192.168.56.11 | Worker node  |
| worker2 | worker2  | 192.168.56.12 | Worker node  |

---

## Canonical Entry Point

All diagnosis and validation for Milestone 01 begins here:

```bash
make verify
```

**“Working” is defined exclusively by verification scripts.**

Manual success (ping, SSH, visual confirmation) does **not** override verification failure.

---

## What Was Built (Concrete Artifacts)

* A Vagrantfile defining three Ubuntu VMs with static IPs
* Idempotent provisioning scripts
* Enforced hostname resolution (`hosts.sh`)
* Host-level verification script (`verify-host.sh`)
* Cluster-level verification script (`verify-cluster.sh`)
* Executable runbooks with real commands

---

## Lab Guarantees

Milestone 01 guarantees the following invariants:

* A reproducible 3-VM lab that can be destroyed and rebuilt from zero
* Stable node identity (hostnames and IPs do not drift)
* Host → VM connectivity verified externally
* VM ↔ VM connectivity verified by **hostname**, not IP
* Idempotent provisioning (safe to re-run at any time)
* Deterministic hostname resolution enforced by automation
* Clear PASS / FAIL output when invariants break

### One-Glance Guarantees

| Scenario                  | Expected Outcome          |
| ------------------------- | ------------------------- |
| VM recreated              | IP and hostname unchanged |
| Provisioning re-run       | No breakage               |
| Host cannot reach VM      | Verification fails        |
| VM cannot resolve peer    | Verification fails        |
| Manual fix without script | Still fails verification  |

---

## Verification as Contract

Verification defines **truth** for this milestone.

* Verification is executed from the **host**
* Verification scripts are authoritative
* A green verification run is the only accepted definition of correctness
* Verification explicitly detects:

  * reachability
  * identity
  * hostname resolution
  * logic mismatches

---

## Failure Domains Covered

| ID  | Failure Domain                      | Detected By          |
| --- | ----------------------------------- | -------------------- |
| T01 | Host cannot reach VM (network / IP) | `verify-host.sh`     |
| T02 | SSH into VM fails                   | `verify-host.sh`     |
| T03 | VM ↔ VM hostname resolution broken  | `verify-cluster.sh`  |
| T04 | Verification logic mismatch         | verification scripts |

Recovery procedures are documented in:

```
docs/runbooks/troubleshooting.md
```

---

## Control Boundary

Milestone 01 establishes a strict control boundary:

* All validation happens **from the host**
* VMs are treated as managed infrastructure, not operator workstations
* Manual SSH is for debugging and drills only

---

## Non-Negotiable Operating Rules

These rules are absolute:

* `/etc/hosts` must **never** be edited manually
* Hostname resolution is enforced via provisioning (`hosts.sh`)
* Provisioning must be safe to re-run at any time
* `.vagrant/` is local state and must never be committed
* Debugging starts with verification, not guesswork

Violating these rules invalidates the milestone.

---

# Operational Runbook — Milestone 01 (Host-Driven)

This runbook documents **expected operational behavior**.
It is not a tutorial.

All commands are executed from the **host machine** unless stated otherwise.

---

## Golden Path (Host)

```bash
make destroy
make up
make provision
make verify
```

Expected outcome:

* All VMs boot
* Provisioning completes without errors
* Verification passes with clear PASS output

---

## VM Reachability Verification (Host)

```bash
ping 192.168.56.10
ping 192.168.56.11
ping 192.168.56.12
```

Expected:

* All pings succeed
* Failure here must cause `make verify` to fail

---

## Hostname Verification (Cluster)

From host:

```bash
make ssh-control
hostname
```

Expected:

* Output: `control`

Repeat for `worker1` and `worker2`.

---

## Failure Drills (Deliberate and Repeatable)

Failure is treated as a **first-class condition**, not an accident.

---

### Failure Drill 01 — Break Host → VM Connectivity

**Reproduction**

* Power off one VM in VirtualBox (or block its network)

**Verification**

```bash
make verify
```

**Expected Behavior**

* Verification fails
* Failure message identifies unreachable VM

**Recovery**

```bash
make up
make verify
```

---

### Failure Drill 02 — Break VM ↔ VM Hostname Resolution

**Reproduction**

* Temporarily comment out hostname provisioning logic (`hosts.sh`)
* Re-run provisioning

```bash
make provision
make verify
```

**Expected Behavior**

* Host verification passes
* Cluster verification fails on hostname resolution

**Recovery**

* Restore `hosts.sh`
* Re-run provisioning and verification

---

### Failure Drill 03 — Re-run Provisioning Safely

**Reproduction**

```bash
make provision
make provision
make verify
```

**Expected Behavior**

* No breakage
* Verification remains green

---

## Acceptance Criteria

Milestone 01 is complete only if **all** of the following are true:

* `make destroy && make up && make provision && make verify` succeeds
* Re-running provisioning does not break the lab
* All nodes resolve each other by hostname
* At least one controlled failure is reproduced and recovered
* Runbooks contain executable commands (not prose)
* Verification output is deterministic and unambiguous

Only after **all criteria** are met may this milestone be merged.

---

## Reviewer Notes

This milestone deliberately avoids application complexity.

The value lies in:

* deterministic identity
* enforced invariants
* verification-first debugging
* reproducible failure

This foundation is what makes later operational guarantees meaningful.

---

## Final Assessment

Milestone 01 converts “I have some VMs” into:

> “I have a deterministic, verifiable lab environment I can trust.”

Without this milestone, higher-level correctness is impossible.

---