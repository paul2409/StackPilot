# StackPilot M9 Phase 2 — Metrics Foundation

## Purpose

Phase 2 turns Phase 1 from design into real signal.

Phase 1 defined what must be observed. Phase 2 makes that data exist so later dashboards, alerts, drills, and incident response are built on real measurements. In the milestone PDF, this is the metrics foundation step: application, pod/container, node, and ingress/controller behavior must become measurable 

## Objective

Make the StackPilot platform measurable at five layers:

* application
* dependency
* platform
* cluster
* ingress

## Finish Line

Phase 2 is done when:

* Prometheus is running
* scrape targets are healthy
* all six services are observable
* node and workload metrics exist
* ingress metrics exist
* wallet and identity dependency paths are visible
* labels are clean enough for dashboards later

---

## 1. What Must Be Measurable

| Layer       | What Must Be Visible                                                |
| ----------- | ------------------------------------------------------------------- |
| Application | liveness, readiness, request/error behavior, version where possible |
| Dependency  | postgres-wallet and postgres-identity impact on service readiness   |
| Platform    | deployments, pods, restarts, rollout health                         |
| Cluster     | node readiness, CPU, memory                                         |
| Ingress     | request volume, edge errors, controller health                      |

---

## 2. Coverage Scope

All services must be watched. Wallet-service stays the main incident anchor, but M9 must cover the full platform.

| Component          | Minimum Requirement                            |
| ------------------ | ---------------------------------------------- |
| identity-service   | workload + health/readiness visibility         |
| wallet-service     | workload + health/readiness visibility         |
| system-service     | workload + health/readiness visibility         |
| customer-portal    | workload + health/readiness visibility         |
| admin-portal       | workload + health/readiness visibility         |
| ops-portal         | workload + health/readiness visibility         |
| postgres-identity  | workload state + dependency symptom visibility |
| postgres-wallet    | workload state + dependency symptom visibility |
| ingress/controller | traffic + error visibility                     |
| nodes              | readiness + resource visibility                |

---

## 3. Metrics Strategy

### Minimum Foundation

You must have:

* Prometheus
* workload and pod metrics
* node metrics
* ingress metrics
* service liveness/readiness visibility
* usable labels

### Stronger Foundation

Where possible, also add:

* request count
* error count
* latency
* version/build visibility

### Priority for Stronger App Metrics

1. wallet-service
2. identity-service
3. system-service
4. customer-portal
5. ops-portal
6. admin-portal

---

## 4. Signal Sources

| Signal Type                | Source                                         |
| -------------------------- | ---------------------------------------------- |
| service health/readiness   | app endpoints / probes                         |
| request/error behavior     | app metrics or ingress metrics                 |
| deployment/pod state       | kube-state metrics                             |
| restarts / waiting reasons | kube-state metrics                             |
| node health                | node metrics                                   |
| ingress traffic/errors     | ingress controller metrics                     |
| DB-related symptoms        | service readiness failures + DB workload state |

---

## 5. Required Metrics Layers

### Application

Must show:

* which service is alive
* which service is ready
* which service is receiving traffic or failing

### Dependency

Must show:

* wallet DB failure symptoms
* identity DB failure symptoms
* readiness degradation caused by dependencies

### Platform

Must show:

* desired vs available replicas
* pod state
* restart count
* rollout problems

### Cluster

Must show:

* node readiness
* CPU and memory pressure

### Ingress

Must show:

* request flow
* error rates
* controller health

---

## 6. Labels and Identity

Metrics must be attributable by:

* namespace
* app/service name
* workload/deployment
* pod
* node
* version if available

If services cannot be separated cleanly in metrics, Phase 2 is not done.

---

## 7. Scrape Target Contract

### Mandatory Targets

* Prometheus self-metrics
* Kubernetes/workload state metrics
* node metrics
* ingress/controller metrics
* service-truth source for health/readiness
* DB-related signal source

### Valid Target Rule

A scrape target counts only if:

* it is up
* it has useful labels
* it supports a real operator question

---

## 8. Implementation Order

### Step 1

Install Prometheus.

### Step 2

Enable workload and node metrics.

### Step 3

Enable ingress metrics.

### Step 4

Make all six services visible at health/readiness level.

### Step 5

Add stronger app metrics for the priority services.

### Step 6

Check label quality.

### Step 7

Verify raw data before moving to dashboards.

---

## 9. Verification Contract

Phase 2 must prove raw signal exists before Phase 3 starts.

| Check                     | Pass Condition                              |
| ------------------------- | ------------------------------------------- |
| Prometheus reachable      | running and healthy                         |
| scrape targets healthy    | expected targets are up                     |
| workload metrics visible  | deployments, pods, restarts visible         |
| node metrics visible      | readiness and resource data visible         |
| ingress metrics visible   | traffic/error/controller data visible       |
| service coverage complete | all six services identifiable               |
| wallet anchor visible     | wallet readiness + workload state visible   |
| identity anchor visible   | identity readiness + workload state visible |
| labels usable             | services and workloads separate cleanly     |

### Failure Signs

Phase 2 is not complete if:

* only self-metrics exist
* services cannot be separated
* ingress is not measurable
* wallet and identity paths are not diagnosable
* labels are messy

---

## 10. Done Criteria

Phase 2 is complete when StackPilot can say:

“We now have real raw signal for the six services, both main dependencies, the ingress path, the workloads, and the cluster. Dashboards and alerts can now be built on actual data.”

That is the correct goal of the metrics-foundation stage in the observability milestone 

---
