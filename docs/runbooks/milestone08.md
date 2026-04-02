Milestone 08 — GitOps + Multi-Environment + Artifact Promotion

⸻

Purpose

Git is the single source of truth. Argo CD reconciles cluster state automatically. Manual deployments are eliminated.

**At this stage:**
	•	Git defines desired state (values, manifests, promotion decisions)
	•	CI produces immutable SHA-tagged artifacts
	•	Argo CD continuously enforces cluster state to match Git
	•	Promotion: dev → staging via Git branch movement
	•	No rebuilds, only image tag promotion

⸻

System Model

Three authorities with clear responsibilities:

**1. CI — Artifact Authority**
	•	Builds images, tags with commit SHA, pushes to GHCR
	•	Updates environment values files
	•	Does NOT deploy to cluster

**2. Git — Source of Truth**
	•	Defines desired deployment state
	•	Stores Helm values per environment
	•	Controls promotion via branch movement

**3. Argo CD — Reconciler**
	•	Watches Git, applies desired state, detects drift, self-heals

⸻

Environment & Repository

Single cluster, two environments (dev + staging):
	•	Each has own namespace, Argo CD Application, values file
	•	Both use same Helm chart
	•	Branch flow: milestone → dev → main

Repository structure:
	•	helm/stackpilot/ — Chart + values-dev.yaml, values-staging.yaml
	•	argocd/ — stackpilot-dev.yaml, stackpilot-staging.yaml
	•	artifacts/releases/ — current-dev.txt, current-staging.txt

⸻

CI Workflow

**Dev Build + Deploy** (trigger: push to dev)
	•	Detect changed services
	•	Build images, tag as sha-<commit>
	•	Push to GHCR, update values-dev.yaml, write current-dev.txt
	•	Argo CD reconciles dev automatically

**Staging Promote + Deploy** (trigger: push to main)
	•	Read artifact state from dev
	•	Copy image tags into values-staging.yaml
	•	Write current-staging.txt
	•	Argo CD reconciles staging (no rebuild)

⸻

Artifact Promotion

Key rule: **Staging MUST run the same artifact that dev validated.**

Format for release visibility:

	service=image:tag
	wallet-service=ghcr.io/paul2409/wallet-service:sha-abc123

Verification:

	kubectl get deploy -n stackpilot-dev -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'
	kubectl get deploy -n stackpilot-staging -o jsonpath='{range .items[*]}{.metadata.name}{" -> "}{range .spec.template.spec.containers[*]}{.image}{" "}{end}{"\n"}{end}'
	cat artifacts/releases/current-dev.txt
	cat artifacts/releases/current-staging.txt

⸻

GitOps Behavior

	•	Desired state: Defined in Git (values files + manifests)
	•	Reconciliation: Argo CD continuously aligns live state to Git
	•	Drift: Manual cluster changes are overwritten
	•	Self-heal: Deleted resources are recreated by Argo CD
	•	Promotion: Git-based (dev → main controls when staging updates)
	•	Rollback: Git revert, automatic reconciliation (no manual cluster repair)

⸻

Failure Handling & Recovery

	•	CI failures block artifact updates
	•	Argo CD applies only valid Git state
	•	Broken deployments surface as failing pods / readiness failures
	•	Recovery: Git revert + automatic reconciliation
	•	Drift recovery: Namespace deletion test — Argo CD recreates namespace and redeploys

⸻

Completion Criteria

Milestone 08 is complete when:
	•	Dev and staging both run successfully
	•	CI builds and pushes SHA-tagged images
	•	Dev deploys new artifacts automatically
	•	Staging deploys promoted artifacts only
	•	Both environments can be inspected and compared
	•	Drift recovery works (namespace deletion test)
	•	Promotion uses the same artifact identity
	•	Rollback via Git revert is verified	
	
	
End-to-End GitOps + Promotion + Failure Demo

Purpose

This runbook proves the full GitOps delivery loop:
	•	CI builds artifacts
	•	Dev deploys first
	•	Staging receives promoted artifact
	•	Failure is observable
	•	Rollback restores system

This is the final proof that the system behaves correctly under change and failure.

⸻

Demo Flow

1. Change + Build + Dev Deploy

git checkout -b m18-demo
# make small change in wallet-service
git add .
git commit -m "m18: demo change"
git push origin m18-demo

git checkout dev
git merge m18-demo
git push origin dev

Verify:

kubectl get pods -n stackpilot-dev
kubectl describe deployment wallet-service -n stackpilot-dev | grep Image

Expected:
	•	New SHA deployed in dev

⸻

2. Promote to Staging

git checkout main
git merge dev
git push origin main

Verify:

kubectl describe deployment wallet-service -n stackpilot-staging | grep Image

Expected:
	•	Same SHA as dev

⸻

3. Inject Failure (Dev Only)

Break image tag:

wallet-service:
  image: ghcr.io/paul2409/wallet-service:sha-broken

git add .
git commit -m "m18: break wallet-service"
git push origin dev

Verify failure:

kubectl get pods -n stackpilot-dev
kubectl describe pod <pod> -n stackpilot-dev

Expected:
	•	ImagePullBackOff / CrashLoopBackOff

⸻

4. Rollback (Git Revert)

git revert HEAD
git push origin dev

Verify recovery:

kubectl get pods -n stackpilot-dev -w
kubectl describe deployment wallet-service -n stackpilot-dev | grep Image

Expected:
	•	Pods recover
	•	Previous SHA restored

⸻

5. Staging Safety Check

kubectl get pods -n stackpilot-staging

Expected:
	•	Staging remains healthy
	•	No broken rollout

⸻

What This Proves
	•	CI builds once → SHA artifact
	•	Dev consumes new artifact first
	•	Staging receives same promoted artifact
	•	Failure is visible and contained
	•	Rollback is Git-driven
	•	ArgoCD self-heals system

⸻

End State
	•	Git is the only control plane
	•	ArgoCD enforces desired state
	•	Environments are isolated
	•	Artifact promotion is deterministic
	•	Recovery is reliable

⸻

