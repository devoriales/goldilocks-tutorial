# Lesson 06: The Goldilocks Dashboard

> **Duration**: ~20 minutes | **Level**: Beginner | [← Lesson 05](../05-enable-and-observe/) | [Next →](../07-applying-recommendations/)

## Overview

The Goldilocks dashboard is where raw VPA numbers become actionable insights. It shows you exactly how your current resource settings compare to VPA's recommendations, and generates ready-to-paste YAML for both Guaranteed and Burstable QoS configurations.

**Prerequisites:** Completed Lesson 05 (namespace labeled, VPA objects have recommendations).

---

## Learning Objectives

- Access the Goldilocks dashboard via port-forward
- Read the comparison tables (current vs recommended)
- Understand what Guaranteed and Burstable YAML snippets mean
- Identify which deployments are over-provisioned vs under-provisioned

---

## Step 1: Open the Dashboard

```bash
kubectl -n goldilocks port-forward svc/goldilocks-dashboard 8080:80
```

Leave this running in your terminal. Open a browser and navigate to:

```
http://localhost:8080
```

You'll be redirected to `http://localhost:8080/namespaces`.

---

## Step 2: Navigate to the Namespace

The namespaces page lists all namespaces with the `goldilocks.fairwinds.com/enabled=true` label. You should see **metrics-app** listed.

Click **metrics-app** to open the dashboard for that namespace.

---

## What You'll See

The dashboard URL is:

```
http://localhost:8080/dashboard/metrics-app
```

The page shows one section per deployment. Each deployment section has:
- The deployment name
- A **Guaranteed QoS** comparison table
- A **Burstable QoS** comparison table
- A copy-pasteable YAML snippet for each

---

## Reading the Comparison Tables

The table format is: **[current setting]** → [icon] → **[recommended value]**

- `<` icon (warning): current value is **lower** than recommended (under-provisioned)
- `>` icon (warning): current value is **higher** than recommended (over-provisioned)

### frontend — Over-Provisioned

```
Guaranteed QoS:
  CPU Request:    500m  >  15m    ← 33× over-provisioned
  CPU Limit:      500m  >  15m
  Memory Request: 512Mi >  100Mi  ← 5× over-provisioned
  Memory Limit:   512Mi >  100Mi
```

The frontend (nginx serving static files) consumes almost no CPU. The current setting of `500m / 512Mi` is massively over-provisioned. The Goldilocks YAML for Guaranteed mode:

```yaml
resources:
  requests:
    cpu: 15m
    memory: 100Mi
  limits:
    cpu: 15m
    memory: 100Mi
```

### api — Under-Provisioned Requests

```
Guaranteed QoS:
  CPU Request:    10m   <  126m   ← 12× under-provisioned
  CPU Limit:      200m  >  126m   ← limit is fine
  Memory Request: 32Mi  <  156Mi  ← under-provisioned
  Memory Limit:   128Mi <  156Mi  ← too low, OOMKill risk!
```

The api pod requests only `10m` CPU but uses `~126m`. It's being severely CPU throttled under load. Also the memory limit of `128Mi` is below VPA's target of `156Mi` — this pod could OOMKill. The YAML for Guaranteed:

```yaml
resources:
  requests:
    cpu: 126m
    memory: 156Mi
  limits:
    cpu: 126m
    memory: 156Mi
```

### worker — Under-Provisioned CPU, Mixed Memory

```
Guaranteed QoS:
  CPU Request:    50m   <  163m   ← 3× under-provisioned
  CPU Limit:      1000m >  163m   ← overly generous limit
  Memory Request: 32Mi  <  100Mi  ← under-provisioned
  Memory Limit:   128Mi >  100Mi  ← slightly over-provisioned
```

The worker runs a tight CPU loop and needs `163m` CPU, but only requests `50m` — it will always be throttled. The YAML for Guaranteed:

```yaml
resources:
  requests:
    cpu: 163m
    memory: 100Mi
  limits:
    cpu: 163m
    memory: 100Mi
```

---

## Guaranteed vs Burstable YAML

The dashboard generates two YAML snippets per deployment:

### Guaranteed QoS

Requests equal limits. The pod gets a fixed resource allocation. Kubernetes guarantees these resources will always be available to the pod.

```yaml
resources:
  requests:
    cpu: 126m      # = VPA target
    memory: 156Mi  # = VPA target
  limits:
    cpu: 126m      # = requests
    memory: 156Mi  # = requests
```

**Best for:** Latency-sensitive services, databases, anything that needs predictable performance.

### Burstable QoS

Requests are set to VPA's `lowerBound` (minimum safe), limits are set to VPA's `upperBound`. The pod can burst above its request up to the limit when resources are available.

```yaml
resources:
  requests:
    cpu: 19m       # = VPA lowerBound
    memory: 100Mi  # = VPA lowerBound
  limits:
    cpu: 9658m     # = VPA upperBound (still converging — see below)
    memory: 11944Mi
```

> ⚠️ **Burstable limits are often unrealistically high early on.** The `upperBound` from VPA takes approximately 8 days of data to converge. In the example above, `9658m CPU` and `11944Mi memory` for an httpbin container is not realistic. When using Burstable mode, set limits manually based on your knowledge of the workload, not blindly from the upper bound. See Lesson 09 for the full guidance.

**Best for:** Batch jobs, background workers, services with variable load.

---

## The Cost Estimation Feature

The dashboard includes an optional cost estimation sidebar. You can enter:
- A cloud provider (AWS, GCP)
- Instance type
- Or manual cost per CPU-hour and cost per GB of memory

This shows you the approximate monthly cost of your current configuration vs the recommended configuration. For our over-provisioned frontend with `500m CPU / 512Mi` memory, the savings from dropping to `15m CPU / 100Mi` are significant.

> 💡 The cost estimation is best-effort and assumes 100% resource usage. Treat it as a directional indicator, not a billing forecast.

---

## Verification

With the port-forward running:

```bash
# Dashboard is accessible
curl -sL http://localhost:8080/namespaces | grep metrics-app
# Should return HTML containing: metrics-app

# Dashboard shows deployment data
curl -sL http://localhost:8080/dashboard/metrics-app | grep -c "Deployment"
# Should return: 4 (one per deployment)
```

---

## Stop the Port-Forward

When done, press `Ctrl+C` in the terminal running the port-forward. The dashboard pod continues running — you can port-forward again any time.

---

## What's Next

In [Lesson 07](../07-applying-recommendations/), you'll take the recommended YAML from the dashboard and apply it to the actual deployments. You'll observe pods restart with new resource settings and verify the QoS class has changed.
