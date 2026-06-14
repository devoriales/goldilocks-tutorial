# Lesson 09: Production Considerations

> **Duration**: ~15 minutes | **Level**: Intermediate | [← Lesson 08](../08-advanced-configuration/) | [Cheatsheet →](../goldilocks-cheatsheet/)

## Overview

The hardest part of using Goldilocks in production isn't installation — it's knowing when to trust a recommendation and when to override it. This lesson covers the practical rules that keep you from under-provisioning production workloads while still capturing real cost savings.

---

## Learning Objectives

- Understand VPA's 8-day convergence window and why it matters
- Build a safe workflow for applying recommendations in production
- Extract recommendations programmatically for CI/CD automation
- Know the scenarios where Goldilocks recommendations should never be blindly applied

---

## The 8-Day Rule

VPA's recommendation algorithm is based on a percentile model of observed usage. The key insight:

- **`target`** (the recommended request value): Converges relatively quickly — useful after 24-48 hours of representative load
- **`upperBound`** (used for Burstable limits): Requires ~8 days of data to converge, because it models worst-case usage across a full weekly cycle

Until 8 days of data exist, the `upperBound` is extrapolated from a small sample, which causes massive over-estimates. You saw this in Lesson 03: `19955m CPU` and `24Gi memory` for a container that actually uses ~126m CPU and ~156Mi memory.

**The practical rule:**

| Data age | Trust `target`? | Trust `upperBound`? | Action |
|----------|----------------|---------------------|--------|
| < 24h | ❌ | ❌ | Wait |
| 1–7 days | ✅ (for requests) | ❌ | Use `target` for requests; set limits manually at 2–3× target |
| 8+ days | ✅ | ✅ (verify first) | Use both — still sanity-check against known workload peaks |

Check how long a VPA has been collecting data:

```bash
kubectl get vpa goldilocks-frontend -n metrics-app \
  -o jsonpath='{.metadata.creationTimestamp}'
# 2026-06-14T09:15:40Z
```

---

## Workloads Where Recommendations Need Extra Care

Not all workloads are safe to resize based solely on recent history:

### Seasonal / Batch Workloads
A Black Friday traffic spike, a month-end report job, or a weekly sync — if VPA only saw off-peak usage, the recommendation will be insufficient for peak. Always cross-reference with known peak load patterns before applying.

### Startup-Sensitive Workloads
Some applications (JVM, Python with large imports) use significantly more CPU and memory at startup than at steady state. VPA averages across the pod lifetime, potentially recommending values that cause slow starts or OOMKills at pod creation.

**Mitigation:** Check resource usage in the first 2-3 minutes of pod startup separately, and add a buffer above VPA's `target` for memory.

### Stateful Services
Databases and caches often have memory usage patterns that grow over time (caches fill up, WAL grows). VPA's recommendation based on today's usage may be insufficient in 6 months.

### Low-Replica Deployments
A single-replica deployment loses all traffic when its pod is evicted. Even in `Off` mode, applying recommendations that require a pod restart should be timed carefully (off-peak, with PodDisruptionBudget in place).

---

## Extracting Recommendations Programmatically

For CI/CD pipelines and GitOps workflows, you don't need the dashboard — you can read VPA recommendations directly from the Kubernetes API.

### Get the target recommendation for a specific deployment

```bash
kubectl get vpa goldilocks-frontend -n metrics-app \
  -o jsonpath='{.status.recommendation.containerRecommendations[0].target}'
```

Output:

```json
{"cpu":"15m","memory":"100Mi"}
```

### Get all recommendations as JSON

```bash
kubectl get vpa -n metrics-app -o json | \
  python3 -c "
import json, sys
vpas = json.load(sys.stdin)
for vpa in vpas['items']:
    name = vpa['metadata']['name'].replace('goldilocks-', '')
    recs = vpa.get('status', {}).get('recommendation', {}).get('containerRecommendations', [])
    for r in recs:
        print(f'{name}/{r[\"containerName\"]}: target={r[\"target\"]}')
"
```

Output:

```
api/httpbin: target={'cpu': '126m', 'memory': '163378051'}
frontend/nginx: target={'cpu': '15m', 'memory': '100Mi'}
load-generator/load-generator: target={'cpu': '23m', 'memory': '100Mi'}
worker/worker: target={'cpu': '163m', 'memory': '100Mi'}
```

### CI/CD Integration Pattern

A common pattern in GitOps pipelines:

1. A scheduled job (e.g., weekly) runs a script that reads VPA recommendations
2. The script compares current deployment values against recommendations
3. If drift exceeds a threshold (e.g., current is >2× or <0.5× the recommendation), it opens a PR updating the manifest
4. A human reviews and merges the PR
5. The CD pipeline applies the change

This keeps humans in the loop while automating the discovery of drift. Tools like [Robusta](https://home.robusta.dev/) and [Kyverno](https://kyverno.io/) can assist with steps 2-4.

---

## What to Do Before Applying to Production

Follow this checklist before applying any Goldilocks recommendation to a production deployment:

```
□ VPA data is at least 8 days old (for upper bounds) or 48h (for request targets)
□ Observation window covered a representative traffic period (including weekly peaks)
□ Recommendation reviewed against known workload behavior (startup cost, seasonal peaks)
□ Memory reduction staged: apply in steps (e.g., 512Mi → 300Mi → 150Mi, with monitoring between)
□ PodDisruptionBudget (PDB) is in place if the deployment has <3 replicas
□ Change applied outside business hours for latency-sensitive services
□ Rollback plan ready: kubectl rollout undo deployment/<name> -n <namespace>
□ Monitoring alert exists for OOMKill (exit code 137) and CrashLoopBackOff
```

---

## Monitoring Recommendations Over Time

After applying a recommendation, watch for:

```bash
# OOMKilled pods (exit code 137 = out of memory)
kubectl get pods -n metrics-app \
  --field-selector=status.phase=Failed \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[0].lastState.terminated.exitCode}{"\n"}{end}'

# CrashLoopBackOff
kubectl get pods -n metrics-app | grep CrashLoopBackOff

# Recent restarts
kubectl get pods -n metrics-app \
  -o custom-columns="NAME:.metadata.name,RESTARTS:.status.containerStatuses[0].restartCount"
```

Set up alerts in your monitoring stack (Prometheus + Alertmanager or Datadog) for:
- `kube_pod_container_status_last_terminated_reason{reason="OOMKilled"} > 0`
- `kube_pod_container_status_restarts_total` growing faster than expected

---

## Running Goldilocks Alongside Prometheus

Goldilocks and VPA both read from the Metrics API (`kubectl top`). For long-term recommendation quality, Prometheus with long retention is better than the Metrics API alone. The Prometheus Adapter can serve historical metrics to VPA, giving it months of data rather than the default ~8-day window.

This is an advanced topic beyond this tutorial's scope, but worth knowing: if your cluster runs Prometheus, configure [VPA with historical data](https://github.com/kubernetes/autoscaler/blob/master/vertical-pod-autoscaler/README.md#using-prometheus-as-a-history-provider) to dramatically improve recommendation accuracy.

---

## Summary: When Goldilocks Works Best

✅ **Great fit:**
- Microservices with steady, observable traffic patterns
- Long-running deployments (8+ days of history)
- Teams who want data-driven starting points for resource values
- Clusters with over-provisioning problems (common in teams that set resources once and forget)

⚠️ **Use with care:**
- Seasonal workloads or infrequent batch jobs
- Services with memory that grows over months
- Single-replica production deployments (restart risk)
- Very new services (< 1 week old)

❌ **Goldilocks doesn't help:**
- Setting requests for pod initialization containers
- Recommending resources for `Job` / `CronJob` based on per-run duration
- Replacing domain knowledge about peak load requirements

---

## What's Next

You've completed the tutorial! Head to the **[Cheatsheet](../goldilocks-cheatsheet/)** for a quick reference of every command and pattern from this tutorial.
