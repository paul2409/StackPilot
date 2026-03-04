Good.

Now we’re talking properly.

You don’t want “pass Milestone 07.”

You want:

• 10/10 Kubernetes fundamentals
• Helm literacy
• CRD understanding
• Ingress + networking clarity
• Runtime reasoning depth
• Not just “it works” but “I understand why it works”

That changes the structure.

We will redesign Milestone 07 as:

Milestone 07 — Kubernetes Runtime Mastery (Local, Deep Mode)

Still aligned to the locked milestone definition :
“Kubernetes enforces runtime guarantees (local).”

But now we elevate it.

We are not adding complexity randomly.
We are layering it intentionally.

You will learn:

1. Core primitives deeply
2. Controllers and reconciliation
3. Networking model
4. Ingress model
5. Storage model
6. Helm templating
7. CRDs (Custom Resource Definitions)
8. Advanced rollout behavior
9. Runtime debugging under pressure

This will be extensive.

—

STRUCTURE OF THE NEW M07 (10/10 PATH)

We break this into 9 Phases.

Each phase has:

• Technical objective
• Concept objective (what you must understand)
• Deliverables
• Failure drills
• Mastery signals

—

PHASE 0 — Mental Model Upgrade (Before Installing Anything)

Objective:
You must understand what Kubernetes actually is.

Core Concepts You Must Internalize:

• Control Plane vs Worker Nodes
• Desired State vs Actual State
• Controllers
• Reconciliation Loop
• etcd (state store)
• API Server as single source of truth
• Scheduler
• kubelet
• Service abstraction

If you cannot explain:

“What happens from kubectl apply to a running pod?”

You are not ready to move.

Deliverable:
docs/m07/concepts.md
Write this in your own words.

Mastery Signal:
You can explain the reconciliation loop clearly.

—

PHASE 1 — Cluster Architecture Deep Setup (k3s on 3 VMs)

Objective:
Understand what you’re installing.

You will:

• Install k3s server on control
• Install agents on worker1 + worker2
• Inspect system pods
• Inspect kube-system namespace
• Understand embedded datastore

Concept Focus:

• What is a node?
• What is a control plane?
• Where does state live?
• What is a kubelet?
• What is a CNI (network plugin)?

Deliverables:

• docs/m07/cluster-architecture.md
• runbooks/k3s-debug-basics.md

Failure Drill:

Stop k3s service on one worker.
Observe node NotReady.
Understand why.

Mastery Signal:

You can explain how traffic is routed between nodes.

—

PHASE 2 — Pods, Deployments, ReplicaSets (Core Runtime)

Objective:
Master the most fundamental objects.

You will create:

• A bare Pod
• A Deployment
• Observe ReplicaSet behavior

Concept Focus:

• Why Pods are ephemeral
• Why you never deploy Pods directly in production
• What ReplicaSet guarantees
• Why Deployment wraps ReplicaSet
• RollingUpdate strategy

Failure Drill:

Delete Pods manually.
Observe automatic recreation.

Mastery Signal:

You understand the difference between:
Pod → ReplicaSet → Deployment

—

PHASE 3 — Probes, Lifecycle, and Honest Runtime Semantics

Objective:
Make your API production-correct.

You will implement:

• livenessProbe
• readinessProbe
• startupProbe (optional)
• lifecycle hooks (preStop)

Concept Focus:

• Why readiness ≠ liveness
• What happens when readiness fails
• What happens when liveness fails
• Graceful shutdown behavior
• TerminationGracePeriod

Failure Drills:

1. Break DB → readiness fails only
2. Force liveness failure → pod restarts
3. Kill container process → restart

Mastery Signal:

You can predict exactly what Kubernetes will do before it does it.

—

PHASE 4 — Networking Deep Dive (Cluster Networking + Services)

Objective:
Understand internal networking model.

You will work with:

• ClusterIP Services
• NodePort Services
• DNS resolution
• kube-dns/CoreDNS

Concept Focus:

• How Service selects pods (labels!)
• What Endpoints are
• kube-proxy behavior
• iptables/ipvs routing
• Service discovery by DNS

Failure Drills:

1. Wrong label selector → no endpoints
2. Delete service → DNS fails
3. Curl from inside pod vs outside

Mastery Signal:

You can diagram packet flow from:
Host → NodePort → Service → Pod

—

PHASE 5 — Storage & Stateful Systems

Objective:
Handle Postgres correctly in Kubernetes.

You will implement:

• PersistentVolumeClaim
• local-path provisioner (k3s default)
• StatefulSet (not just Deployment)
• Headless Service

Concept Focus:

• Why StatefulSet exists
• Stable network identity
• Volume binding lifecycle
• Pod ordinal identity

Failure Drills:

1. Restart DB pod → data persists
2. Delete PVC → data loss (expected)
3. Scale StatefulSet → understand identity

Mastery Signal:

You understand why DB is different from API.

—

PHASE 6 — Ingress + Advanced Networking

Objective:
Move beyond NodePort.

You will:

• Install ingress controller (Traefik already included in k3s or install NGINX)
• Create Ingress resource
• Route traffic by hostname
• Add TLS (self-signed for lab)

Concept Focus:

• L7 routing
• Difference between Service and Ingress
• Controller watching Ingress resources
• Reverse proxy model
• TLS termination

Failure Drills:

1. Bad host rule → 404
2. Remove backend service → 503
3. Misconfigured TLS

Mastery Signal:

You can explain:
Why Ingress is not a load balancer.

—

PHASE 7 — Helm (Real-World Packaging)

Objective:
Stop writing raw YAML only.

You will:

• Install Helm
• Create a Helm chart for your API
• Template:

* image tag
* replica count
* resource limits
* env vars
  • Use values.yaml for environment control

Concept Focus:

• Templating
• Release lifecycle
• Helm upgrade vs install
• Chart structure

Failure Drill:

Upgrade with bad values.
Rollback Helm release.

Mastery Signal:

You can explain:
Why Helm is not a package manager, but a release manager.

—

PHASE 8 — CRDs and Controllers (Advanced Level)

Objective:
Understand extensibility.

You will:

• Install a simple CRD (example: cert-manager or ArgoCD CRD introspection)
• Inspect CustomResourceDefinition object
• Understand how controllers watch CRDs

Concept Focus:

• Kubernetes is an API platform
• Controllers reconcile custom resources
• Operator pattern

Failure Drill:

Inspect CRD status conditions.
Understand why status subresource exists.

Mastery Signal:

You understand Kubernetes is extensible, not fixed.

—

PHASE 9 — Production-Grade Runtime Guarantees (10/10 Seal)

Objective:
Prove real runtime strength.

You will demonstrate:

• Rolling updates without downtime
• Failed rollout blocked by readiness
• Resource pressure behavior
• HPA (Horizontal Pod Autoscaler)
• Pod disruption budgets
• Node drain behavior

Concept Focus:

• Scheduling decisions
• Resource requests vs limits
• Evictions
• Self-healing
• Autoscaling logic

Failure Drills:

1. Set low memory limit → OOMKill → observe restart
2. Drain worker node → pods reschedule
3. Bad image tag → rollout blocked

Mastery Signal:

You can reason about system behavior before running commands.

—

FINAL EXIT CONDITION (10/10 VERSION)

You must be able to:

• Explain control plane architecture
• Explain reconciliation loop
• Design probes correctly
• Debug networking issues
• Deploy via Helm
• Understand CRDs
• Perform safe rollouts
• Handle stateful workloads
• Simulate production failures

And the app must:

• Survive pod churn
• Enforce readiness truth
• Persist state
• Roll out safely
• Be reachable via Ingress
• Be installable via Helm

That is 10/10 local Kubernetes mastery.

—

Now I need to calibrate the teaching depth.

Answer these honestly:

1. Do you want command-first learning (type → observe → explain),
   or theory-first (explain deeply → then implement)?

2. How many hours per day are you willing to invest during this milestone?

3. Are you comfortable reading Kubernetes official docs if I assign sections?

We’re not doing surface-level learning.

If you want elite-level competence, we build it deliberately.





Good. I’ll write it back clean, structured, and calibrated — Socratic style, with your real resource names.

Namespace: stackpilot
Deployment: mock-exchange
Container: api
Service: mock-exchange

We proceed drill by drill.

⸻

DRILL 1 — Delete a Pod (Self-Heal)

Question: What actually recreates the pod — the Deployment or the ReplicaSet?
Answer: The ReplicaSet (which is owned by the Deployment).

Commands:
	•	kubectl -n stackpilot get deploy mock-exchange -o wide
	•	kubectl -n stackpilot get pods -l app=mock-exchange -o wide
	•	kubectl -n stackpilot delete pod 
	•	kubectl -n stackpilot get pods -l app=mock-exchange -w

Correct Observation:
	•	Deleted pod goes Terminating.
	•	A new pod appears with a new name.
	•	Replicas return to 2/2.
	•	Service remains usable if you have ≥2 replicas.

What this proves: Controllers enforce desired replica count.

⸻

DRILL 2 — Update Image (New ReplicaSet)

Question: Why does changing the image create a new ReplicaSet?
Answer: Because the PodTemplate changed. A new RS is created so the Deployment can perform a controlled rollout.

Commands:
	•	kubectl -n stackpilot get rs -l app=mock-exchange
	•	kubectl -n stackpilot rollout status deploy/mock-exchange
	•	kubectl -n stackpilot set image deploy/mock-exchange api=ghcr.io/paul2409/mock-exchange:
	•	kubectl -n stackpilot rollout status deploy/mock-exchange
	•	kubectl -n stackpilot get rs -l app=mock-exchange

Correct Observation:
	•	New ReplicaSet appears.
	•	Old RS scales down gradually.
	•	Readiness gates progression (new pods must become Ready before old ones terminate).

What this proves: Deployment uses immutable RS revisions for safe rollouts.

⸻





