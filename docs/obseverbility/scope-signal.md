# StackPilot M9 Phase 1 — Observability Scope and Signal Design

## Purpose

M9 is now **Observability + Alerting Closure** in your locked order. Its purpose is to make reliability measurable, alerts actionable, recovery documented, and incident response provable. The original milestone text defines this observability stage as the point where you can tell which service is unhealthy, which service is not ready, which dependency is broken, which service is erroring, and what changed after deployment; it also requires that a real alert fires, routes correctly, recovery happens, and the incident is documented 

Phase 1 exists to lock the observability boundary before tools are installed. This phase defines what must be watched, which failure classes matter, what dashboards must answer, and which future alerts are worth having. This matches the broader StackPilot model where verification defines reality, health and readiness must be truthful, and observability must close the loop from detection to notification to recovery  

## Phase 1 Objective

Lock the full observed system, operator questions, signal layers, dependency chains, failure classes, dashboard contracts, and alert principles for the StackPilot six-service platform before installing Prometheus, Grafana, or Alertmanager.

## Phase 1 Finish Line

Phase 1 is complete when the following are true:

* the observed platform boundary is fixed
* all critical services and dependencies are named
* operator questions are defined
* signals are grouped into clear layers
* dependency propagation is mapped
* dashboard families are defined before they are built
* future alert classes are justified
* wallet-service remains the main incident anchor, but all services are included in monitoring scope

---

## 1. Observed Platform Boundary

StackPilot M9 does not observe “a cluster” in the abstract. It observes the six-service platform, its critical data dependencies, and the request-entry path.

The goal is not to prove that pods exist. The goal is to prove:

* service truth
* readiness truth
* dependency truth
* propagation truth
* release impact visibility
* recovery visibility

The observed boundary must include the six-service runtime described in the continuation plan, plus both Postgres dependencies and ingress/controller behavior 

### Observed Components Table

| Component | Type | Role | Why it Must Be Watched |
|---|---|---|---|
| identity-service | application | auth & identity service | breaks auth path and user access |
| wallet-service | application | wallet and balance anchor | main incident/drill anchor for readiness propagation |
| system-service | application | system state summary | cross-service health and dependency summary |
| customer-portal | application | user portal | shows customer-facing degradation fast |
| admin-portal | application | admin portal | shows admin/internal operational impact |
| ops-portal | application | ops diagnostics surface | operator-facing truth and dependency summaries |
| postgres-identity | dependency | identity DB | root dependency for identity path |
| postgres-wallet | dependency | wallet DB | primary root dependency for M9 incident path |
| ingress/controller | platform edge | request entry path | detects routing edge vs internal service issues |
| deployments/pods/services | platform | k8s runtime objects | rollout failures, crashes, restart loops, availability issues |
| nodes | cluster | worker/control substrate | cluster-level causes vs service-level causes |

### Boundary Statement

StackPilot M9 observes all six services equally as monitored runtime components, while using **wallet-service + postgres-wallet** as the primary incident anchor because that dependency chain produces the clearest end-to-end failure propagation story for drills and alert design. This follows the milestone text, which uses wallet-service readiness and wallet DB failure as the strongest examples for actionable alerting and incident closure

---

## 2. Operator Questions

Every future dashboard panel, metric, and alert must answer one of these questions. If it answers none of them, it is noise.

### Core Operator Questions

1. Which services are alive right now?
2. Which services are actually ready to serve?
3. Which dependency is broken when readiness fails?
4. Which services are degraded because of downstream dependency loss?
5. Which workloads are restarting, flapping, or unstable?
6. Are requests reaching ingress and services normally?
7. Which services are erroring and how badly?
8. Did a deployment, config change, or version change trigger the degradation?
9. Is the issue application-level, dependency-level, platform-level, or cluster-level?
10. Has recovery actually restored readiness, traffic, and stability?

### Question-to-Outcome Table

| Question | Outcome |
|---|---|
| Which services are alive? | process exists |
| Which services are ready? | safe routing |
| Which dependency is broken? | root-cause direction |
| Which services degraded because of downstream failure? | propagation and blast radius |
| Which workloads are unstable? | rollout/crash-loop diagnosis |
| Are requests flowing normally? | user-impact visibility |
| Which services are erroring? | service urgency and impact |
| Did deployment trigger the issue? | rollback/release investigation |
| What layer is failing? | app vs DB vs platform vs cluster |
| Has recovery worked? | closure verification |

---

## 3. Signal Layers

Signals must be separated into layers so you do not confuse symptoms with causes.

### Signal Layer Model

| Layer       | Purpose                            | Typical Questions                                        |
| ----------- | ---------------------------------- | -------------------------------------------------------- |
| Application | observes service behavior          | is the service alive, ready, erroring, or slow?          |
| Dependency  | observes backing service truth     | is a database or downstream dependency the cause?        |
| Platform    | observes workload/runtime behavior | are deployments available, restarting, or crash-looping? |
| Cluster     | observes infrastructure substrate  | are nodes, ingress, or scheduling causing the issue?     |

### Full Signal Inventory

| Layer | Signal | Why It Matters | Likely Source Later |
| --- | --- | --- | --- |
| Application | `/health` status per service | proves process liveness | service probe / metrics |
| Application | `/ready` status per service | proves dependency-aware readiness | service probe / metrics |
| Application | request rate per service | shows whether traffic is flowing | app metrics / ingress metrics |
| Application | error rate per service | shows impact severity | app metrics / ingress metrics |
| Application | latency per service | shows performance degradation | app metrics / ingress metrics |
| Application | service version/build | correlates behavior with release changes | `/version`, labels, annotations |
| Dependency | postgres-wallet availability symptom | main root-cause anchor | db exporter / readiness symptom |
| Dependency | postgres-identity availability symptom | identity-path root cause | db exporter / readiness symptom |
| Dependency | DB connectivity failures from services | connects app failures to DB truth | app logs / app metrics / readiness |
| Dependency | dependency propagation state | shows which upstream services became unready | service readiness comparisons |
| Platform | deployment desired vs available | identifies rollout failure | kube-state metrics |
| Platform | pod phase/state | indicates unhealthy workloads | kube-state metrics |
| Platform | restart count | shows crash loops / instability | kube-state metrics |
| Platform | container waiting reason | shows image/probe/startup issues | kube-state metrics |
| Platform | service reachability | checks runtime exposure path | service/endpoints metrics |
| Platform | ingress route health | shows whether requests reach apps | ingress metrics |
| Cluster | node readiness | distinguishes cluster failure from app failure | node/k8s metrics |
| Cluster | node CPU/memory | shows substrate pressure | node exporter |
| Cluster | namespace workload state | gives platform-wide health summary | kube-state metrics |
| Cluster | ingress/controller availability | identifies edge/routing failures | ingress controller metrics |

### Signal Priority Rules

Signals are not equally important. Priority order for M9 is:

1. readiness truth
2. dependency truth
3. request/error impact
4. workload stability
5. release correlation
6. generic resource pressure

That ordering fits the continuation plan’s emphasis on readiness, dependency-aware failure, and actionable diagnosis rather than generic “dashboard noise” 

---

## 4. Service Criticality and Dependency Mapping

All services must be watched. But they do not play identical operational roles.

### Service Monitoring Model

| Service          | Monitoring Priority | Why                                                     |
| ---------------- | ------------------- | ------------------------------------------------------- |
| wallet-service   | highest             | primary incident anchor and dependency propagation root |
| identity-service | high                | auth-path failure can block core access patterns        |
| system-service   | high                | useful aggregated truth and cross-service summary       |
| customer-portal  | high                | user-facing blast radius signal                         |
| admin-portal     | medium-high         | admin and internal operations impact                    |
| ops-portal       | high                | diagnostics and dependency truth surface                |

### Dependency Map

#### Primary Dependency Chain

`postgres-wallet -> wallet-service -> customer-portal / admin-portal / system-service / ops-portal`

This is the primary M9 incident chain because it gives the clearest example of:

* dependency failure
* readiness failure
* upstream propagation
* dashboard usefulness
* alert usefulness
* runbook usefulness

The milestone text directly supports this by using wallet-service readiness failure and wallet DB failure as the model incident path 

#### Secondary Dependency Chain

`postgres-identity -> identity-service -> customer-portal / auth-dependent admin flows`

This is the secondary identity incident chain.

### Dependency Propagation Expectations

| Root Failure | Immediate Service Impact | Expected Upstream Impact |
| --- | --- | --- |
| postgres-wallet unavailable | wallet-service `/ready` fails | portals/system/ops may show dependency degradation/not-ready |
| postgres-identity unavailable | identity-service `/ready` fails | auth-dependent flows degrade; login/identity lookup may fail |
| wallet-service broken release | rollout unavailable or flapping | upstream consumers degrade; dependency errors |
| identity-service broken release | unstable or unavailable | auth-dependent flows degrade |
| ingress/controller issue | requests fail before services | broad user-facing impact; healthy pods possible |
| node/cluster issue | scheduling/pod availability degrades | multiple unrelated services may degrade together |

### Dependency Monitoring Rule

Wallet-service remains the **main incident anchor**, but M9 must watch:

* both DB-backed services directly
* all three portals as propagation surfaces
* system-service as summary signal
* ops-portal as operator-facing truth surface
* ingress/controller as edge health
* workload and node health as platform context

---

## 5. Mandatory Failure Classes

M9 is not “monitor everything.” It must make specific failure classes visible.

The continuation plan explicitly names the most important alert candidates: wallet-service not ready, system-service not ready, portal not ready, high error rate, repeated restart loops, and DB-down symptom 

### Failure Class Table

| Failure Class | Root Symptom | Expected Downstream Impact | Signals That Must Reveal It | Future Alert Candidate |
| --- | --- | --- | --- | --- |
| Wallet DB unavailable | postgres-wallet unreachable | wallet-service not ready; upstream portal/system/ops degradation | wallet readiness, DB symptom, upstream readiness changes | wallet-service-not-ready, wallet-db-down-symptom |
| Identity DB unavailable | postgres-identity unreachable | identity-service not ready; login/auth degradation | identity readiness, auth-path failures | identity-service-not-ready, identity-db-down-symptom |
| Bad wallet release | wallet-service rollout fails or flaps | wallet-dependent consumers degrade | rollout state, restarts, readiness false, version correlation | wallet-service-rollout-failure |
| Bad identity release | identity-service rollout fails or flaps | auth path breaks | rollout state, readiness false, version correlation | identity-service-rollout-failure |
| Portal service degradation | customer/admin/ops portal not ready or erroring | user/admin/operator-facing issues visible | portal readiness, request errors, restart state | portal-not-ready |
| System-service degradation | system-service readiness or error failure | summary view becomes unreliable | readiness, error rate, restarts | system-service-not-ready |
| Restart loop instability | repeated pod/container restarts | service flapping, false recoveries, noisy user symptoms | restart count, waiting reason, rollout failure | repeated-restart-loop |
| High request error rate | sustained 5xx/4xx abnormality | visible user-facing breakage | request/error metrics, ingress/service errors | high-error-rate |
| Ingress/controller failure | route path unavailable | broad user impact without app crash | ingress health, edge error rates | ingress-degraded |
| Cluster/node pressure failure | node not ready or severe pressure | multiple workloads degrade together | node readiness, resource pressure, namespace state | cluster-degraded |

### Visibility Requirements Per Failure

#### Wallet DB unavailable

Must reveal:

* wallet-service alive but not ready
* wallet-service dependency issue
* upstream readiness impact on portals/system/ops
* alert-worthy symptom
* clear recovery path

#### Identity DB unavailable

Must reveal:

* identity-service alive but not ready
* auth-path degradation
* whether customer/admin access is affected

#### Bad rollout

Must reveal:

* what changed
* which deployment degraded
* readiness stayed false or availability dropped
* version/release timing correlation

#### Restart loop instability

Must reveal:

* sustained restart growth
* workload flapping
* likely startup/probe/image/config problem

#### Request/error issue

Must reveal:

* which service is erroring
* whether ingress or app is the source
* whether it correlates with deployment or dependency loss

---

## 6. Dashboard Contract

Dashboard families must be defined before any dashboard is built. The milestone text already defines the minimum required set: cluster health, pod health, service health/readiness, request/error view, and release/failure view 

### Dashboard Families Table

| Dashboard | Purpose | Must Answer |
|---|---|---|
| Cluster Health | cluster-level substrate view | are nodes healthy, is cluster under pressure, is ingress/controller generally healthy |
| Pod / Workload Health | workload stability view | which deployments are degraded, which pods are restarting, are replicas available |
| Service Health / Readiness | service-truth view | which services are alive, which are ready, which are failing because of dependencies |
| Request / Error View | user-impact and service-impact view | where traffic is flowing, which service is erroring, whether latency/error is rising |
| Release / Failure View | change-correlation view | what changed after deployment, whether version or rollout correlates with failure |

### Dashboard 1 — Cluster Health

#### Questions

* are nodes healthy?
* is the cluster under resource pressure?
* is ingress/controller functioning normally?
* is this problem likely bigger than one service?

#### Minimum Panels

* node readiness
* node CPU
* node memory
* pod count by state
* namespace health summary
* ingress/controller availability or error trend

### Dashboard 2 — Pod / Workload Health

#### Questions

* which deployment is degraded?
* which pods are crash-looping?
* are replicas unavailable?
* is rollout state stable?

#### Minimum Panels

* deployment desired vs available
* unavailable replicas by deployment
* pod restart count by workload
* container waiting reasons
* workload rollout state

### Dashboard 3 — Service Health / Readiness

#### Questions

* which services are alive?
* which services are ready?
* which services lost readiness because of dependency failures?
* is propagation visible across portals/system/ops?

#### Minimum Panels

* per-service `/health`
* per-service `/ready`
* readiness changes over time
* wallet-service readiness anchor panel
* identity-service readiness anchor panel
* portal readiness comparison
* system-service and ops-portal readiness summary

### Dashboard 4 — Request / Error View

#### Questions

* are requests reaching the platform?
* which services are erroring?
* is latency rising?
* is this a user-facing or internal-only problem?

#### Minimum Panels

* request rate by service
* ingress request volume
* response code distribution
* error rate by service
* latency by service
* portal-specific request/error trend

### Dashboard 5 — Release / Failure View

#### Questions

* what changed?
* did deployment/version correlate with readiness drop?
* did restart spikes begin after a rollout?
* is rollback likely needed?

#### Minimum Panels

* version/build markers
* deployment events if available
* restarts over time by workload
* readiness drop after rollout
* error rate after rollout
* release/change timeline notes

### Dashboard Design Rules

* every panel must answer an operator question
* panels should be sparse and operational, not decorative
* readiness is higher priority than generic CPU graphs
* release/failure correlation must exist, not be guessed
* wallet-service is not the only service shown; all six services must appear somewhere in M9 dashboards

---

## 7. Alert Principles

M9 will later include Alertmanager and real alert routing. But before writing alert rules, the principles must be locked.

The milestone requires alerts to be actionable, and the production adaptation contract requires severity, owner, and runbook linkage, with local chat routing as the initial signaling path  

### Alert Validity Rules

An alert is valid only if it meets all of the following:

* it represents meaningful impact or meaningful recovery need
* it maps to a likely owner
* it maps to a runbook or clear first-response path
* it is not purely decorative
* it is not a one-second transient
* it helps separate root cause from downstream symptoms

### Alert Design Priorities

| Priority | Rule                                                                        |
| -------- | --------------------------------------------------------------------------- |
| 1        | readiness and dependency truth are more important than generic infra noise  |
| 2        | root-cause alerts are better than alert storms from every dependent service |
| 3        | critical services and portals all matter; do not over-focus on wallet alone |
| 4        | broad-impact failures deserve higher severity than isolated flaps           |
| 5        | every serious alert must have first checks and recovery steps later         |

### Severity Model

| Severity | Meaning | Typical Cases |
| -------- | ------- | -------------- |
| Critical | broad or major platform degradation | DB dependency loss causing multi-service readiness failure, ingress path failure, cluster-wide issue |
| Warning | important but narrower degradation | single service not ready, sustained restart loop, elevated error rate |
| Info | state-change visibility | deployment completed, version change, recovery event, alert silenced |

### Required Alert Metadata Later

Every serious alert should eventually include:

* alert name
* severity
* owner
* summary
* impact
* first check
* likely cause
* runbook link or runbook ID

### Alert Candidate Set for M9

| Candidate Alert            | Why It Exists                                     |
| -------------------------- | ------------------------------------------------- |
| wallet-service-not-ready   | primary dependency anchor and blast-radius signal |
| identity-service-not-ready | protects auth-path truth                          |
| system-service-not-ready   | detects broken summary/control surface            |
| customer-portal-not-ready  | captures customer-facing degradation              |
| admin-portal-not-ready     | captures admin-facing degradation                 |
| ops-portal-not-ready       | captures operator-facing degradation              |
| wallet-db-down-symptom     | root-cause-oriented dependency alert              |
| identity-db-down-symptom   | identity dependency root alert                    |
| repeated-restart-loop      | catches unstable workloads                        |
| high-error-rate            | catches actual service impact                     |
| ingress-degraded           | catches edge-path failure                         |
| cluster-degraded           | catches substrate-wide problems                   |

### Alert Philosophy Statement

Wallet-service + postgres-wallet remain the main drill anchor because they produce the strongest end-to-end dependency failure story, but M9 alerting must cover all six services, both major databases, ingress/controller, and workload instability. This ensures the milestone reflects actual platform operations rather than a single-service demo.

---

## 8. Service Watch Matrix

This is the strongest way to make sure all services are covered.

### Service Monitoring Coverage Table

| Component | Health | Readiness | Request/Error | Version/Release | Restarts/Stability | Dependency Visibility | Future Alert Priority |
|-----------------|----------------------------|----------|-------------|--------------------------|-----------------|----------------|----------------------|
| identity-service | yes | yes | yes | yes | yes | yes | high |
| wallet-service | yes | yes | yes | yes | yes | yes | highest |
| system-service | yes | yes | yes | yes | yes | yes | high |
| customer-portal | yes | yes | yes | yes | yes | yes | high |
| admin-portal | yes | yes | yes | yes | yes | yes | medium-high |
| ops-portal | yes | yes | yes | yes | yes | yes | high |
| postgres-identity | indirect/direct symptom view | indirect | n/a | n/a | yes if exposed | yes | high |
| postgres-wallet | indirect/direct symptom view | indirect | n/a | n/a | yes if exposed | yes | highest |
| ingress/controller | n/a | edge health | yes | release context if changed | yes | edge-only | high |
| nodes | n/a | n/a | n/a | n/a | cluster stability | substrate-only | medium-high |

### Coverage Rule

A service is not considered “watched” unless M9 eventually gives you visibility into:

* liveness
* readiness
* request or traffic behavior where applicable
* restart or instability behavior
* release/version context
* dependency-related degradation where applicable

---

## 9. Phase 1 Deliverables

Phase 1 produces this single document as the control file for the rest of M9.

This file must serve as the authority for:

* what gets monitored
* what dashboards must answer
* what failure classes must be visible
* what future alerts are worth building
* why wallet-service is the main incident anchor without excluding other services

---

## 10. Phase 1 Done Criteria

Phase 1 is complete only when all of the following are true:

| Done Check | Status Requirement |
| --- | --- |
| Observed platform boundary is fixed | all six services, both DBs, ingress, workloads, nodes included |
| Operator questions are defined | future dashboards and alerts must map back to them |
| Signal layers are mapped | app, dependency, platform, cluster all covered |
| Dependency chains are explicit | wallet and identity chains documented |
| Mandatory failure classes are defined | root symptom and downstream impact both named |
| Dashboard families are locked | cluster, workload, service, request/error, release/failure |
| Alert principles are written | actionable, owner-linked, runbook-linked, non-noisy |
| All services are covered | wallet is anchor, but not sole focus |
| Future M9 phases have a clear target | metrics, dashboards, alerting, drills, incident closure all trace back here |

---

## 11. Final Phase 1 Position

M9 Phase 1 is complete when StackPilot can say:

“We know exactly what we are observing, why we are observing it, which failures matter, how those failures should appear, which dashboards must answer which questions, and which future alerts deserve to exist.”

That is the right foundation for the observability milestone described in the continuation plan, where reliability must become measurable, alerts must become actionable, and recovery must be documented and proven 

---