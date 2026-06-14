# Lesson 03: VPA Fundamentals

> **Duration**: ~15 minutes | **Level**: Beginner | [← Lesson 02](../02-intro-resource-problem/) | [Next →](../04-install-goldilocks/)

## Overview

Goldilocks is a dashboard on top of VPA — not a replacement for it. Before installing Goldilocks, you'll create a VPA object manually to see what the raw data looks like. This teaches you what Goldilocks is doing behind the scenes.

**Prerequisites:** Completed Lesson 02 (cluster running, VPA installed, metrics-app deployed).

---

## Learning Objectives

- Understand VPA update modes and when each is appropriate
- Create a `VerticalPodAutoscaler` object by hand
- Read raw VPA recommendations and understand each field
- Know why Goldilocks uses `Off` mode

---

## VPA vs HPA: Two Different Problems

**HPA (Horizontal Pod Autoscaler)** adds or removes *pod replicas* based on load. It scales out.

**VPA (Vertical Pod Autoscaler)** adjusts the *resource requests and limits* of existing pods. It scales up.

They solve different problems and can be used together, but **do not enable VPA Auto mode and HPA on the same deployment** — they will fight each other for control.

---

## VPA Update Modes

Every VPA object has an `updateMode` that controls how (or whether) recommendations are applied:

| Mode | Behavior | Safe for Production? |
|------|----------|---------------------|
| `Off` | Calculates recommendations, never applies them | ✅ Yes — read-only |
| `Initial` | Sets resources when a pod is first created; never updates running pods | ✅ Usually |
| `Recreate` | Evicts and recreates pods to apply new recommendations | ⚠️ Causes restarts |
| `Auto` | Same as `Recreate` (may change behavior in future) | ⚠️ Causes restarts |

> 💡 **Goldilocks always uses `Off` mode.** It only reads recommendations — it never evicts your pods. This makes it safe to use on any cluster, including production.

---

## Deploy the Sample App

If you haven't deployed the metrics-app yet, do it now:

```bash
bash scripts/deploy-sample-app.sh

# Or manually:
kubectl apply -f sample-app/namespace.yaml
kubectl apply -f sample-app/frontend/
kubectl apply -f sample-app/api/
kubectl apply -f sample-app/worker/
kubectl apply -f sample-app/load-generator/
```

Wait for all pods to be Running:

```bash
kubectl get pods -n metrics-app
```

Expected output — all pods should show `Running`:

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

## Create a Manual VPA Object

Create a VPA for the `api` deployment in `Off` mode:

```bash
kubectl apply -f - <<'EOF'
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: api-vpa-manual
  namespace: metrics-app
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api
  updatePolicy:
    updateMode: "Off"
  resourcePolicy:
    containerPolicies:
    - containerName: "*"
      minAllowed:
        cpu: 10m
        memory: 32Mi
EOF
```

The `resourcePolicy.containerPolicies` block sets a floor on recommendations — VPA will never recommend less than `10m` CPU or `32Mi` memory, even if actual usage is lower.

---

## Read the Raw Recommendation

Wait ~60 seconds, then inspect the VPA object:

```bash
kubectl describe vpa api-vpa-manual -n metrics-app
```

Look for the `Recommendation` section. Here is real output from this tutorial's cluster:

```
Recommendation:
  Container Recommendations:
    Container Name:  httpbin
    Lower Bound:
      Cpu:     17m
      Memory:  100Mi
    Target:
      Cpu:     126m
      Memory:  156Mi
    Uncapped Target:
      Cpu:     126m
      Memory:  156Mi
    Upper Bound:
      Cpu:     19955m
      Memory:  24Gi
```

### Understanding Each Field

| Field | Meaning | Use case |
|-------|---------|----------|
| `lowerBound` | Minimum safe value based on observed usage | Set as `requests` in Burstable config |
| `target` | VPA's best estimate for optimal requests | Use for Guaranteed QoS |
| `uncappedTarget` | Same as target, ignoring `minAllowed`/`maxAllowed` | Diagnostic |
| `upperBound` | Maximum observed usage + buffer | Set as `limits` in Burstable config |

> ⚠️ **The upper bound will be unrealistically high early on.** In this example: `19955m` CPU and `24Gi` memory for an httpbin container that uses ~150m CPU and ~160Mi memory. This is normal. VPA needs approximately **8 days** of data to converge on accurate upper bounds. The `lowerBound` and `target` values are more reliable sooner. See Lesson 09 for the full explanation.

### Container Name vs Deployment Name

Notice the VPA reports `Container Name: httpbin`, not `api`. VPA tracks individual containers by their `spec.containers[].name` — the container name in the deployment spec, not the deployment name.

Check your api deployment to confirm:

```bash
kubectl get deployment api -n metrics-app \
  -o jsonpath='{.spec.template.spec.containers[0].name}'
# Output: httpbin
```

---

## What Goldilocks Adds

Reading raw VPA output via `kubectl describe` works, but it has limitations:

- You must query each VPA object individually
- Memory values appear in bytes, not human-readable units
- There's no visual comparison between current settings and recommendations
- You can't see all namespaces at once

Goldilocks solves all of this with a web dashboard. In Lesson 04, you'll install it.

---

## Cleanup

Delete the manual VPA (Goldilocks will create its own VPAs in Lesson 05):

```bash
kubectl delete vpa api-vpa-manual -n metrics-app
```

---

## Verification

```bash
# Confirm the manual VPA is gone
kubectl get vpa -n metrics-app
# Should return: No resources found in metrics-app namespace.

# Confirm sample app is still running
kubectl get pods -n metrics-app
# All pods should be Running
```

---

## What's Next

In [Lesson 04](../04-install-goldilocks/), you'll install Goldilocks via Helm. Goldilocks will automatically create VPA objects (in `Off` mode) for every deployment in namespaces you label — no manual YAML required.
