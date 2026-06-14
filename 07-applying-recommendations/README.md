# Lesson 07: Applying Recommendations

> **Duration**: ~20 minutes | **Level**: Beginner | [← Lesson 06](../06-goldilocks-dashboard/) | [Next →](../08-advanced-configuration/)

## Overview

Goldilocks never changes your deployments for you — that's intentional. In this lesson, you'll take the recommendations from the dashboard and apply them yourself. You'll patch two deployments, watch the rollout, and confirm the QoS class matches your intent.

**Prerequisites:** Completed Lesson 06 (recommendations visible in dashboard).

---

## Learning Objectives

- Choose between Guaranteed and Burstable QoS for different workload types
- Apply resource changes via `kubectl patch` and deployment manifests
- Verify QoS class after a rollout
- Understand when NOT to blindly apply what the dashboard shows

---

## Choosing a QoS Strategy

Before applying any recommendation, decide which QoS class suits the workload:

| Workload Type | Recommended QoS | Rationale |
|--------------|-----------------|-----------|
| Stateless web server (nginx, static content) | **Guaranteed** | Consistent latency matters; CPU usage is low and predictable |
| API with variable load | **Burstable** | Can burst during traffic spikes; saves cost at idle |
| Background worker (batch, cron) | **Burstable** | Throughput > latency; burst when CPU is available |
| Database, stateful service | **Guaranteed** | Never allow resource contention; predictability critical |
| Development / staging | **BestEffort** | Cost savings over correctness |

---

## Part 1: Apply Guaranteed QoS to the Frontend

The frontend (nginx) is over-provisioned at `500m CPU / 512Mi memory`. VPA recommends `15m CPU / 100Mi memory`. Since nginx serves static files, usage is highly predictable — Guaranteed QoS is ideal.

### Check current state

```bash
kubectl get deployment frontend -n metrics-app \
  -o jsonpath='{.spec.template.spec.containers[0].resources}'
```

Current output:

```json
{"limits":{"cpu":"500m","memory":"512Mi"},"requests":{"cpu":"500m","memory":"512Mi"}}
```

Current QoS class:

```bash
kubectl get pod -n metrics-app -l app=frontend \
  -o jsonpath='{.items[0].status.qosClass}'
# Output: Guaranteed  (requests == limits, but both are wrong)
```

### Apply the patch

```bash
kubectl patch deployment frontend -n metrics-app --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"15m"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"100Mi"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"15m"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"100Mi"}
]'
```

### Wait for rollout

```bash
kubectl rollout status deployment/frontend -n metrics-app --timeout=60s
```

Expected output:

```
Waiting for deployment "frontend" rollout to finish: 1 out of 2 new replicas have been updated...
Waiting for deployment "frontend" rollout to finish: 1 old replicas are pending termination...
deployment "frontend" successfully rolled out
```

### Verify

```bash
kubectl get pod -n metrics-app -l app=frontend \
  -o jsonpath='{.items[0].status.qosClass}'
# Output: Guaranteed  ✅ (same class, different values)

kubectl get pod -n metrics-app -l app=frontend \
  -o jsonpath='{.items[0].spec.containers[0].resources}'
```

Expected resources:

```json
{"limits":{"cpu":"15m","memory":"100Mi"},"requests":{"cpu":"15m","memory":"100Mi"}}
```

---

## Part 2: Apply Burstable QoS to the API

The api (httpbin) has variable traffic from the load generator. It makes sense to keep requests low (to save cost at idle) and allow bursting. We'll use VPA's `lowerBound` for requests and set a conservative limit of roughly 2× the target.

### Dashboard recommendation for api

From the Goldilocks dashboard:

| | Current | Guaranteed rec | Burstable rec (req / limit) |
|-|---------|---------------|---------------------------|
| CPU request | 10m | 126m | 19m / 250m |
| Memory request | 32Mi | 156Mi | 100Mi / 200Mi |

> ⚠️ **Do not use the raw `upperBound` for limits early on.** The dashboard may show `9658m` CPU as the Burstable limit — that's an unconverged early estimate. A safer approach: set limits to 2× the `target` recommendation until you have 8+ days of data.

### Apply Burstable configuration

```bash
kubectl patch deployment api -n metrics-app --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"19m"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"100Mi"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"250m"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"200Mi"}
]'
```

### Wait for rollout

```bash
kubectl rollout status deployment/api -n metrics-app --timeout=60s
```

### Verify QoS is Burstable

```bash
kubectl get pod -n metrics-app -l app=api \
  -o jsonpath='{.items[0].status.qosClass}'
# Output: Burstable  ✅ (requests < limits = Burstable)
```

---

## The Alternative: Edit the Manifest File

The `kubectl patch` approach is useful for one-off changes, but for production you should update the deployment YAML file and commit the change to version control.

The example patched manifests for this tutorial are in `manifests/02-recommendations/`:

```bash
cat manifests/02-recommendations/frontend-patched.yaml
```

```yaml
resources:
  requests:
    cpu: 15m
    memory: 100Mi
  limits:
    cpu: 15m
    memory: 100Mi
```

Apply from the file:

```bash
kubectl apply -f manifests/02-recommendations/frontend-patched.yaml
```

Committing resource changes to version control is important: if a pod is evicted and rescheduled, Kubernetes uses the values in the deployment spec — not what VPA recommends. Goldilocks only advises; you must write the values into your manifests.

---

## Verify All Pods Are Healthy

```bash
kubectl get pods -n metrics-app
```

Expected — all pods Running:

```
NAME                              READY   STATUS    RESTARTS   AGE
api-74bd8c465d-djp6q              1/1     Running   0          30s
api-74bd8c465d-k2jds              1/1     Running   0          20s
frontend-d8cf6fc45-djmgx          1/1     Running   0          50s
frontend-d8cf6fc45-q9vtf          1/1     Running   0          57s
load-generator-6c685fd88b-btljg   1/1     Running   0          22m
worker-fc6d54446-l285s            1/1     Running   0          22m
```

Check QoS for both patched deployments:

```bash
kubectl get pods -n metrics-app \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.qosClass}{"\n"}{end}'
```

Expected:

```
api-74bd8c465d-djp6q              Burstable
api-74bd8c465d-k2jds              Burstable
frontend-d8cf6fc45-djmgx          Guaranteed
frontend-d8cf6fc45-q9vtf          Guaranteed
load-generator-6c685fd88b-btljg   Burstable
worker-fc6d54446-l285s            Burstable
```

---

## Rollback if Something Goes Wrong

If a pod fails to start after applying new resources (e.g., `OOMKilled` immediately after a memory reduction):

```bash
kubectl rollout undo deployment/frontend -n metrics-app
```

This restores the previous deployment spec. Always monitor for a few minutes after applying new resource values — especially memory reductions.

---

## Practice on Killercoda

Want to try this in a browser without any local setup? The Killercoda lab for this lesson has the full stack running with VPA recommendations ready — you just read the numbers, choose the QoS strategy, and apply the patches.

**[→ Open Lab 3/3: Apply Recommendations to Running Deployments](https://killercoda.com/devoriales/course/goldilocks/scenario-3-apply-recommendations)**

The lab takes ~15 minutes and includes automated verification that checks your QoS class assignments.

---

## What's Next

In [Lesson 08](../08-advanced-configuration/), you'll explore advanced Goldilocks configuration: per-namespace VPA settings, excluding specific containers from recommendations, and adjusting the recommendation algorithm's aggressiveness.
