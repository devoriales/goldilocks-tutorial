# Lesson 02: The Resource Requests Problem

> **Duration**: ~10 minutes | **Level**: Beginner | [← Lesson 01](../01-local-k8s-setup/) | [Next →](../03-vpa-fundamentals/)

## Overview

Before we install any tools, we need to understand *why* Kubernetes resource configuration is so difficult to get right — and what happens when we get it wrong.

Meet the **metrics-app team**. They run three services on Kubernetes:

- **frontend** — an nginx web server that barely uses any CPU or memory
- **api** — a Python/Gunicorn HTTP service that handles data requests
- **worker** — a computation service that crunches numbers in bursts

Their cluster is slow, their bills are high, and their pods keep crashing. Sound familiar?

---

## Learning Objectives

By the end of this lesson you will:

- Understand what resource requests and limits control in Kubernetes
- Know the difference between an OOMKill and CPU throttling
- Understand the three QoS classes and when each applies
- See why over-provisioning costs money and under-provisioning causes instability

---

## What Are Resource Requests and Limits?

Every container in Kubernetes can declare two things:

**`requests`** — the amount of CPU and memory the scheduler uses to *place* the pod on a node. A node must have at least this much available capacity.

**`limits`** — the maximum CPU and memory the container is *allowed* to use. Exceeding these has different consequences for CPU vs memory.

```yaml
resources:
  requests:
    cpu: 100m      # Request 100 millicores (0.1 CPU core)
    memory: 128Mi  # Request 128 MiB of memory
  limits:
    cpu: 500m      # Allow up to 500 millicores
    memory: 256Mi  # Allow up to 256 MiB
```

> 💡 **CPU is measured in millicores**: `1000m` = 1 CPU core. `100m` = 10% of one core.

---

## Two Very Different Failure Modes

### OOMKill: The Memory Problem

Memory limits are **hard**. If a container exceeds its memory limit, the Linux kernel **kills the process immediately** (Out Of Memory kill). Kubernetes then restarts the container. You'll see this as `OOMKilled` in `kubectl describe pod`.

```bash
# Detecting an OOMKill
kubectl describe pod <pod-name> | grep -A 5 "Last State"
# Last State: Terminated
#   Reason: OOMKilled
#   Exit Code: 137
```

The metrics-app's `api` service requests only `32Mi` of memory but actually needs ~80Mi to run. Under load, it gets killed repeatedly. Users see errors. Engineers get paged at 3am.

> ⚠️ **Common mistake**: Setting memory limits too low "to save resources." The pod will run fine until load increases, then start OOMKilling. This is especially painful in production.

---

### CPU Throttling: The Silent Slowdown

CPU limits are **soft**. If a container tries to use more CPU than its limit, Linux's CFS (Completely Fair Scheduler) **throttles** it — the container doesn't die, it just gets slower.

The metrics-app's `api` requests only `10m` CPU (1% of one core) but needs ~50m under load. The result: every request is slow. No alerts fire. Engineers don't notice until users complain.

```bash
# Detecting CPU throttling
kubectl top pod -n metrics-app
# If CPU usage regularly hits the limit, the container is being throttled
```

> ⚠️ **Common mistake**: Setting CPU limits too low and wondering why the app is slow even though "CPU usage is low in the dashboard." Throttling reduces usage metrics while degrading performance.

---

### Over-Provisioning: The Hidden Tax

The metrics-app's `frontend` (nginx) requests `500m` CPU and `512Mi` memory. In practice, idle nginx uses about `2m` CPU and `10Mi` memory.

The scheduler sees `500m` reserved on a node. That capacity is unavailable for other pods — even though it's never used. At scale, this forces you to add more nodes to handle the same workload.

The cost: if your cluster runs 50 nginx pods at 500m CPU each, that's 25 reserved CPU cores that sit idle.

---

## QoS Classes: How Kubernetes Prioritizes Eviction

When a node runs low on memory, Kubernetes must evict pods. Which ones get evicted first? It depends on the **Quality of Service (QoS) class**, determined by your resource configuration.

| QoS Class | When Assigned | Eviction Priority | Best For |
|-----------|--------------|-------------------|----------|
| `BestEffort` | No requests or limits set | First to be evicted | Batch jobs, testing |
| `Burstable` | Requests set but less than limits, or partial | Evicted after BestEffort | Variable workloads |
| `Guaranteed` | Requests == limits for ALL containers | Last to be evicted | Production services |

```bash
# Check QoS class of a running pod
kubectl get pod <pod-name> -o jsonpath='{.status.qosClass}'
```

The metrics-app's `frontend` accidentally has Guaranteed QoS (requests == limits), which protects it from eviction. But the settings are wrong — the guarantee is for 500m CPU that nginx never uses.

---

## The Right-Sizing Problem

You know the three failure modes. But how do you know the *right* values?

**The guessing approach** (what most teams do):
- Copy values from the internet or a colleague
- Set something "large enough" to be safe
- Never revisit it

**The data approach** (what Goldilocks enables):
- Run your workload
- Observe actual CPU and memory usage over time
- Set requests based on measured baselines

This is exactly what the **Vertical Pod Autoscaler (VPA)** does — and Goldilocks puts a dashboard on top of it so you can see the recommendations without reading raw YAML.

---

## Verification

No cluster required for this lesson. Confirm your understanding by answering the quiz.

---

## What's Next

In [Lesson 02](../02-local-k8s-setup/), you'll set up a local Kubernetes cluster with k3d and install the prerequisites for Goldilocks: VPA and metrics-server.
