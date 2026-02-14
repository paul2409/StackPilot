## Milestone 05 — AWS Host Deployment & Explicit Verification

# Objective

Provision a minimal EC2 host using Terraform.

Deploy the StackPilot service using Docker Compose.

Verify cloud deployment explicitly (local remains default).

Prove:
	•	Infrastructure authority (Terraform only)
	•	Deterministic deployment
	•	Explicit cloud verification
	•	Liveness vs readiness correctness
	•	Clean destroy

No manual console interaction is allowed.

⸻

# Design Principles
	1.	Local verification remains default.
	2.	AWS verification is explicit.
	3.	No reliance on MODE flags.
	4.	target.env is the cloud contract.
	5.	Terraform is the only infrastructure authority.
	6.	Failure drills must prove correctness, not appearance.

⸻

# Pre-Requisites

The following must exist and work locally:
	•	AWS CLI v2
	•	Terraform
	•	jq
	•	make
	•	curl
	•	SSH client
	•	Valid AWS credentials configured

Validate:

aws sts get-caller-identity
terraform -version
jq --version

If AWS STS fails, stop. Fix credentials.

⸻

# Cloud Target Model

scripts/aws/target-env.sh generates:

artifacts/aws/target.env

Contents:

TARGET_HOST=<public_ip_or_dns>
API_PORT=<port>
BASE_URL=http://$TARGET_HOST:$API_PORT
SSH_HOST=<host>

This file is the only contract used by verify-aws.

Terraform outputs must not be queried during verification.

⸻

# Golden Path

1. Confirm Identity

make aws-sts

Expected:
	•	Account ID printed
	•	PASS message

⸻

2. Provision + Deploy

make aws-run

Must perform:
	•	terraform apply
	•	instance readiness wait
	•	target.env generation
	•	docker compose deployment
	•	BASE_URL printed

No manual SSH steps required.

⸻

3. Explicit Cloud Verification

make verify-aws

This must:
	•	source artifacts/aws/target.env
	•	perform TCP reachability
	•	check:
	•	/health
	•	/ready
	•	/version
	•	create order
	•	retrieve order
	•	verify persistence

On failure:
	•	exit non-zero
	•	print clear failure reason

Local verify remains:

make verify

Cluster checks remain local-only.

⸻

# Failure Drill — DB Midflight Kill

Script location:

scripts/aws/drills/kill-db-midflight.sh

Execution:

./scripts/aws/drills/kill-db-midflight.sh

Expected Behavior:
	1.	/health remains 200
	2.	/ready flips to 503 while DB is stopped
	3.	Order creation fails with 503
	4.	DB restarts
	5.	/ready returns to 200
	6.	Orders table remains
	7.	Data persists

Artifacts should be captured in:

artifacts/drills/

This proves:
	•	Correct liveness separation
	•	Dependency isolation
	•	Persistence durability

⸻


# Exit Criteria

Milestone 05 is complete only if:
	•	aws-sts passes
	•	aws-run provisions and deploys deterministically
	•	verify-aws works using only target.env
	•	Failure drill behaves correctly
	•	aws-destroy removes everything cleanly
	•	Documentation is sufficient for third-party reproduction
	•	No console interaction required

