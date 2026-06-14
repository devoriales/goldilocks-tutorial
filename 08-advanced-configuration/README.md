# Lesson 08: Advanced Configuration

> **Duration**: ~15 minutes | **Level**: Intermediate | [← Lesson 07](../07-applying-recommendations/) | [Next →](../09-production-considerations/)

## Overview

In lessons 02-07 you ran Goldilocks in its default opt-in mode — one label per namespace. In production you'll often want cluster-wide coverage with specific exclusions, filtered dashboard views, and minimum resource floors. This lesson covers the configuration knobs that matter at scale.

**Prerequisites:** Completed Lesson 04 (Goldilocks installed).

---

## Learning Objectives

- Switch Goldilocks from opt-in to opt-out (on-by-default) mode
- Exclude system namespaces and specific workload types
- Filter sidecar containers from the dashboard
- Set minimum resource floors via VPA resource policy
- Understand what Goldilocks does NOT support per-deployment

---

## Configuration Overview

Goldilocks configuration lives in two places:

| Layer | Configured via | Affects |
|-------|---------------|---------|
| Controller flags | Helm values (`controller.flags`) | Which namespaces get VPAs |
| Dashboard flags | Helm values (`dashboard.excludeContainers`) | What the UI shows |
| VPA resource policy | Manual VPA edit | Minimum/maximum bounds per container |

There is **no per-deployment annotation** in Goldilocks v4.15.x to exclude individual deployments or change their VPA mode. Control is at the namespace and controller level.

---

## On-By-Default Mode

By default, Goldilocks only manages namespaces you explicitly label. For a large cluster with many teams, this means constantly chasing new namespaces. The `on-by-default` flag inverts this:

```yaml
# Add to your Helm values or upgrade command
controller:
  flags:
    on-by-default: "true"
    exclude-namespaces: "kube-system,kube-public,goldilocks,vpa,cert-manager"
```

Apply via Helm upgrade:

```bash
helm upgrade goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  --version 10.4.0 \
  -f manifests/01-goldilocks/values.yaml \
  --set 'controller.flags.on-by-default=true' \
  --set-string 'controller.flags.exclude-namespaces=kube-system' \
  --wait
```

Verify the flags are active:

```bash
kubectl describe deployment goldilocks-controller -n goldilocks | grep -A 10 "Command:"
```

Expected — controller starts with both flags:

```
Command:
  /goldilocks
  controller
  -v2
  --exclude-namespaces=kube-system
  --on-by-default=true
```

> ⚠️ **Do not enable `on-by-default` without exclusions.** System namespaces (`kube-system`, `goldilocks`, `vpa`) contain components that VPA should not monitor. The `--exclude-namespaces` flag is required alongside `--on-by-default`.

---

## Excluding Specific Controller Kinds

By default, Goldilocks creates VPAs for `Deployment` workloads only. You can extend it to other kinds or further restrict it:

```bash
# Ignore DaemonSets cluster-wide (they usually can't change resource per-replica anyway)
helm upgrade goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  -f manifests/01-goldilocks/values.yaml \
  --set 'controller.flags.ignore-controller-kind=DaemonSet'
```

Available controller kinds you can ignore: `Deployment`, `DaemonSet`, `StatefulSet`, `ReplicaSet`, `CronJob`.

---

## Filtering Sidecar Containers from the Dashboard

In service mesh environments (Istio, Linkerd), every pod has a sidecar proxy container. Goldilocks will show recommendations for sidecars alongside your app containers, which adds noise. The dashboard supports an exclusion list:

```yaml
dashboard:
  excludeContainers: "linkerd-proxy,istio-proxy,envoy"
```

Apply:

```bash
helm upgrade goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  -f manifests/01-goldilocks/values.yaml \
  --set 'dashboard.excludeContainers=linkerd-proxy,istio-proxy'
```

This only affects what the **dashboard displays** — the underlying VPA objects still track the sidecar containers.

---

## Setting Minimum Resource Floors

VPA may recommend very low values (e.g., `1m` CPU) for idle containers. In practice, you often want a minimum floor — no container should run with less than `10m` CPU or `32Mi` memory regardless of VPA's suggestion.

You can add a `resourcePolicy` to the VPA objects Goldilocks creates. However, since Goldilocks manages VPA objects and will overwrite manual edits, the correct approach is to use a post-sync step or admission webhook.

The alternative that works without fighting Goldilocks: set `minAllowed` at the Helm values level — currently Goldilocks does not directly support `minAllowed` per-container via its flags, so you apply it by editing the VPA directly after Goldilocks creates it:

```bash
kubectl patch vpa goldilocks-api -n metrics-app --type='merge' -p='{
  "spec": {
    "resourcePolicy": {
      "containerPolicies": [
        {
          "containerName": "*",
          "minAllowed": {
            "cpu": "10m",
            "memory": "32Mi"
          }
        }
      ]
    }
  }
}'
```

> ⚠️ **Goldilocks will overwrite manual VPA edits** during its next reconciliation cycle (usually within 30-60 seconds). For durable resource policy floors, configure them in a separate VPA object that you manage independently alongside Goldilocks. Alternatively, use Polaris or OPA/Gatekeeper to enforce a minimum on the deployment itself.

---

## Include-Namespaces for Scoped Rollout

If you want Goldilocks to only manage specific namespaces regardless of labels, use `include-namespaces`:

```bash
helm upgrade goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  -f manifests/01-goldilocks/values.yaml \
  --set-string 'controller.flags.include-namespaces=production,staging'
```

When `include-namespaces` is set, only those namespaces are monitored — the namespace label is ignored. This is useful for a controlled rollout: start with `staging`, verify behavior, then add `production`.

---

## What Goldilocks Does NOT Support

Knowing the limits prevents frustration:

| Feature | Supported? | Alternative |
|---------|-----------|-------------|
| Per-deployment exclusion via annotation | ❌ | Remove deployment from namespace, or restructure namespaces |
| Per-deployment VPA mode override via annotation | ❌ | Create a manual VPA for that deployment alongside Goldilocks |
| StatefulSet VPA management | ❌ | Create VPA objects manually (Lesson 03) |
| DaemonSet VPA management | ❌ | Create VPA objects manually |
| Automatic resource patching | ❌ | Intentional — Goldilocks is always advisory |
| durable VPA resourcePolicy via Goldilocks | ❌ | Use a separate admission controller or Gatekeeper policy |

---

## Reset to Default Configuration

To return to the simple configuration from earlier lessons:

```bash
helm upgrade goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  --version 10.4.0 \
  -f manifests/01-goldilocks/values.yaml \
  --wait
```

---

## Verification

```bash
# Check active controller flags
kubectl describe deployment goldilocks-controller -n goldilocks | grep -A 10 "Command:"

# Helm release status
helm list -n goldilocks

# VPAs still present
kubectl get vpa -n metrics-app
```

---

## What's Next

In [Lesson 09](../09-production-considerations/), you'll learn how to use Goldilocks safely in production: the 8-day convergence rule, CI/CD integration patterns, multi-cluster considerations, and when to trust (or distrust) a recommendation.
