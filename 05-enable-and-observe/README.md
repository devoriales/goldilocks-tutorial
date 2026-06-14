# Lesson 05: Enable and Observe

> **Duration**: ~15 minutes | **Level**: Beginner | [← Lesson 04](../04-install-goldilocks/) | [Next →](../06-goldilocks-dashboard/)

## Overview

Goldilocks is opt-in per namespace. In this lesson, you'll add a single label to the `metrics-app` namespace, watch Goldilocks create VPA objects automatically within seconds, and read your first real recommendations from the command line.

**Prerequisites:** Completed Lesson 04 (Goldilocks installed and running).

---

## Learning Objectives

- Understand Goldilocks's namespace label mechanism
- Label a namespace and observe VPA objects appear automatically
- Read VPA recommendations from `kubectl` output
- Understand what the controller creates vs what you create manually

---

## The Activation Label

Goldilocks uses a single Kubernetes namespace label as its trigger:

```
goldilocks.fairwinds.com/enabled=true
```

When the Goldilocks controller detects this label on a namespace, it:
1. Lists all `Deployment` objects in that namespace
2. Creates a `VerticalPodAutoscaler` object for each one
3. Names each VPA: `goldilocks-<deployment-name>`
4. Sets the VPA's update mode to `Off`

When you remove the label, the controller deletes those VPA objects.

---

## Step 1: Deploy the Sample App

If you haven't deployed `metrics-app` yet, do so now:

```bash
bash scripts/deploy-sample-app.sh
```

Wait for all pods to be Running:

```bash
kubectl get pods -n metrics-app
```

Expected:

```
NAME                              READY   STATUS    RESTARTS   AGE
api-56b68c8cd4-rttnr              1/1     Running   0          2m
api-56b68c8cd4-xn6db              1/1     Running   0          2m
frontend-5ff778b849-rkrbm         1/1     Running   0          2m
frontend-5ff778b849-s8j99         1/1     Running   0          2m
load-generator-6c685fd88b-btljg   1/1     Running   0          2m
worker-fc6d54446-l285s            1/1     Running   0          2m
```

---

## Step 2: Label the Namespace

```bash
kubectl label namespace metrics-app goldilocks.fairwinds.com/enabled=true
```

Confirm the label was applied:

```bash
kubectl get namespace metrics-app --show-labels
```

Expected output:

```
NAME          STATUS   AGE   LABELS
metrics-app   Active   5m    app.kubernetes.io/part-of=metrics-app-tutorial,goldilocks.fairwinds.com/enabled=true,kubernetes.io/metadata.name=metrics-app
```

---

## Step 3: Watch VPA Objects Appear

Within 5-10 seconds, Goldilocks creates a VPA for each deployment. Watch it happen:

```bash
kubectl get vpa -n metrics-app --watch
```

You'll see VPA objects appear one by one:

```
NAME                        MODE   CPU   MEM   PROVIDED   AGE
goldilocks-api              Off                           2s
goldilocks-frontend         Off                           2s
goldilocks-load-generator   Off                           2s
goldilocks-worker           Off                           2s
```

Press `Ctrl+C` to exit the watch.

After ~60 seconds, the `PROVIDED` column changes to `True` as VPA starts computing recommendations:

```bash
kubectl get vpa -n metrics-app
```

```
NAME                        MODE   CPU    MEM         PROVIDED   AGE
goldilocks-api              Off    126m   163378051   True       58s
goldilocks-frontend         Off    15m    100Mi       True       58s
goldilocks-load-generator   Off    23m    100Mi       True       58s
goldilocks-worker           Off    163m   100Mi       True       58s
```

> 💡 The `MEM` column shows bytes for some values (e.g., `163378051` = ~156Mi) and human-readable for others. This is normal — it depends on whether VPA has enough data to apply its rounding algorithm. The Goldilocks dashboard shows everything in human-readable format.

---

## Step 4: Inspect a Recommendation

Let's look at the **frontend** deployment. Our manifest sets requests at `500m CPU / 512Mi memory` — intentionally over-provisioned. What does VPA recommend?

```bash
kubectl describe vpa goldilocks-frontend -n metrics-app
```

Look for the `Recommendation` section:

```
Recommendation:
  Container Recommendations:
    Container Name:  nginx
    Lower Bound:
      Cpu:     15m
      Memory:  100Mi
    Target:
      Cpu:     15m
      Memory:  100Mi
    Uncapped Target:
      Cpu:     15m
      Memory:  100Mi
    Upper Bound:
      Cpu:     934m
      Memory:  977097667
```

**Reading this:**
- The frontend container (named `nginx`) is currently set to `500m CPU / 512Mi memory`
- VPA recommends only `15m CPU / 100Mi memory` as the target
- That's a **33× reduction in CPU requests** and a **5× reduction in memory** — the classic over-provisioning problem
- The `upperBound` at `934m CPU` is still large (8-day convergence), but the `target` is already very informative

---

## Step 5: Inspect the Worker Recommendation

The `worker` pod runs a CPU-intensive Python computation loop. Let's see what it needs:

```bash
kubectl describe vpa goldilocks-worker -n metrics-app
```

```
Recommendation:
  Container Recommendations:
    Container Name:  worker
    Lower Bound:
      Cpu:     138m
      Memory:  100Mi
    Target:
      Cpu:     163m
      Memory:  100Mi
    Uncapped Target:
      Cpu:     163m
      Memory:  100Mi
    Upper Bound:
      Cpu:     13862m
      Memory:  978036964
```

The worker's current manifest sets `requests: 50m CPU / 32Mi memory`. VPA recommends `163m CPU` — the worker is **under-provisioned by 3×** and will be constantly CPU throttled. This is exactly the problem Goldilocks is designed to surface.

---

## Inspect the VPA Object Goldilocks Created

Goldilocks-managed VPAs have specific labels that identify their source:

```bash
kubectl get vpa goldilocks-api -n metrics-app -o yaml
```

Notice the metadata labels:

```yaml
metadata:
  labels:
    creator: Fairwinds
    source: goldilocks
  name: goldilocks-api
  namespace: metrics-app
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  updatePolicy:
    updateMode: "Off"
```

The `creator: Fairwinds` and `source: goldilocks` labels let you distinguish Goldilocks-managed VPAs from any manual VPAs you create. The `updateMode: "Off"` confirms Goldilocks never touches your pods.

---

## What Gets a VPA and What Doesn't

The Goldilocks controller creates VPAs for **Deployments only**. It does not create VPAs for:

- `StatefulSet`
- `DaemonSet`
- `Job` / `CronJob`
- `ReplicaSet` (use Deployment)

If you have StatefulSets you want recommendations for, create VPA objects manually (as you did in Lesson 03) with `updateMode: "Off"`.

---

## Disable Goldilocks for a Namespace

To stop Goldilocks from managing a namespace, remove the label:

```bash
kubectl label namespace metrics-app goldilocks.fairwinds.com/enabled-
```

> The trailing `-` removes the label. Within seconds, Goldilocks deletes all the VPA objects it created in that namespace. Your deployments and pods are unaffected.

For this tutorial, keep the label in place — the dashboard in Lesson 06 needs it.

---

## Verification Checklist

```bash
# Namespace has the label
kubectl get namespace metrics-app --show-labels | grep goldilocks

# Four VPA objects exist (one per deployment)
kubectl get vpa -n metrics-app
# Should show: goldilocks-api, goldilocks-frontend, goldilocks-load-generator, goldilocks-worker

# At least one has PROVIDED=True (recommendations available)
kubectl get vpa -n metrics-app | grep True

# All VPAs are in Off mode (Goldilocks never applies changes)
kubectl get vpa -n metrics-app -o jsonpath='{range .items[*]}{.metadata.name}{": "}{.spec.updatePolicy.updateMode}{"\n"}{end}'
# Every line should end with: Off
```

---

## Practice on Killercoda

Want to try this in a browser without any local setup? The Killercoda lab for this lesson deploys the sample app with intentionally wrong resource settings and gives you a running Goldilocks stack — you just activate the namespace and read the results.

**[→ Open Lab 2/3: Enable a Namespace and Observe Recommendations](https://killercoda.com/devoriales/course/goldilocks/scenario-2-enable-and-observe)**

The lab takes ~15 minutes and includes automated step verification.

---

## What's Next

In [Lesson 06](../06-goldilocks-dashboard/), you'll port-forward the Goldilocks dashboard to your local machine and use the web UI to view recommendations, compare them to current settings, and generate ready-to-use YAML patches.
