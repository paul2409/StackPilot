MILESTONE 01 — LAB FOUNDATION RUNBOOK

Purpose
This runbook defines the operational scope, guarantees, and failure boundaries for
Milestone 01 of StackPilot. This milestone establishes a deterministic 3-VM lab
that all later milestones depend on.

If this milestone is unstable, DO NOT proceed to Week 2.

----------------------------------------------------------------

LAB TOPOLOGY (AUTHORITATIVE)

Node      Hostname   IP               Role
------------------------------------------------
control   control    192.168.56.10    Control node
worker1   worker1    192.168.56.11    Worker node
worker2   worker2    192.168.56.12    Worker node

----------------------------------------------------------------

CANONICAL ENTRY POINT

All diagnosis and validation for Milestone 01 starts here:

make verify

“Working” for this milestone is defined ONLY by verification scripts.
Manual success does not override verification failure.

----------------------------------------------------------------

WHAT MILESTONE 01 GUARANTEES

• A reproducible 3-VM lab that can be destroyed and rebuilt from zero  
• Stable node identity (hostnames and IPs do not drift)  
• Host → VM connectivity validated externally  
• VM ↔ VM connectivity validated by hostname, not IP  
• Idempotent provisioning (safe to re-run)  
• Deterministic hostname resolution enforced by automation  
• Clear PASS / FAIL output when invariants break  

----------------------------------------------------------------

FAILURE DOMAINS COVERED

ID    Failure Domain                               Detected By
---------------------------------------------------------------
T01   Host cannot reach VM (network/IP)            verify_host
T02   SSH into VM fails                            verify_host
T03   VM ↔ VM hostname resolution broken           verify_cluster
T04   Verification logic mismatch                  verify scripts

Recovery procedures for all failures live in:
docs/runbooks/troubleshooting.md

----------------------------------------------------------------

NON-NEGOTIABLE OPERATING RULES

• /etc/hosts must NEVER be edited manually  
• Hostname resolution is enforced via provisioning (hosts.sh)  
• Provisioning must be safe to re-run at any time  
• .vagrant/ is local state and must never be committed  
• Debugging starts with verification, not guesswork  

----------------------------------------------------------------

REQUIRED ARTIFACTS FOR THIS MILESTONE

• Vagrantfile defining 3 VMs with static IPs  
• Idempotent provisioning scripts  
• Host and cluster verification scripts  
• Enforced hostname resolution script  
• Executable runbooks with real commands  

----------------------------------------------------------------

EXIT CRITERIA (ALL MUST BE TRUE)

• make destroy && make up && make provision && make verify succeeds  
• Re-running provisioning does not break the lab  
• All nodes resolve each other by hostname  
• At least one controlled failure was reproduced and recovered  
• Runbooks contain executable commands (not prose)  

Only after ALL criteria are met may this milestone be merged.
