# Lesson 04: Installing Goldilocks

> **Duration**: ~15 minutes | **Level**: Beginner | [← Lesson 03](../03-vpa-fundamentals/) | [Next →](../05-enable-and-observe/)

## Overview

Goldilocks has two components: a **controller** that manages VPA objects, and a **dashboard** that presents recommendations in a web UI. In this lesson, you'll install both via Helm and verify they're running correctly.

**Prerequisites:** Completed Lesson 02 (cluster running, VPA installed).

---

## Learning Objectives

- Install Goldilocks via the official Helm chart
- Understand the difference between the controller and dashboard components
- Know the critical image registry change in Goldilocks v4.15.x
- Verify the installation is healthy

---

## How Goldilocks Works

```
┌─────────────────────────────────────────────────────────┐
│  Your Cluster                                           │
│                                                         │
│  ┌──────────────────┐    creates    ┌───────────────┐  │
│  │ Goldilocks       │ ──────────►  │ VPA objects   │  │
│  │ Controller       │               │ (Off mode)    │  │
│  └──────────────────┘               └───────┬───────┘  │
│                                             │           │
│                                      reads  │           │
│                                             ▼           │
│  ┌──────────────────┐    reads    ┌───────────────┐    │
│  │ Goldilocks       │ ──────────► │ VPA           │    │
│  │ Dashboard        │             │ Recommendations│    │
│  └──────────────────┘             └───────────────┘    │
└─────────────────────────────────────────────────────────┘
```

1. You label a namespace with `goldilocks.fairwinds.com/enabled=true`
2. The **controller** detects the label and creates a VPA object for each Deployment in that namespace
3. VPA's recommender watches the pods and computes resource recommendations
4. The **dashboard** reads all VPA objects and presents recommendations as a web UI

---

## Step 1: Create the Namespace

```bash
kubectl create namespace goldilocks
```

---

## Step 2: Prepare the Helm Values

Create a values file at `manifests/01-goldilocks/values.yaml`:

```yaml
image:
  repository: us-docker.pkg.dev/fairwinds-ops/oss/goldilocks
  tag: v4.15.1

vpa:
  enabled: false        # We installed VPA separately in Lesson 02

metrics-server:
  enabled: false        # We installed metrics-server separately in Lesson 02
```

> ⚠️ **Critical: Registry Change in v4.15.x**
>
> The old image registry `quay.io/fairwinds/goldilocks` was **deprecated in v4.15.0** and will fail to pull. Always use:
> ```
> us-docker.pkg.dev/fairwinds-ops/oss/goldilocks:v4.15.1
> ```
> If you use the Helm chart defaults without specifying `image.repository`, the chart will use the correct registry automatically. The override above is explicit for clarity.

The `vpa.enabled: false` and `metrics-server.enabled: false` flags prevent Goldilocks from installing its own bundled versions of VPA and metrics-server — we already have those from Lesson 02.

---

## Step 3: Install Goldilocks

```bash
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo update fairwinds-stable

helm install goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  --version 10.4.0 \
  -f manifests/01-goldilocks/values.yaml \
  --wait \
  --timeout 180s
```

Expected output:

```
NAME: goldilocks
LAST DEPLOYED: Sun Jun 14 11:13:58 2026
NAMESPACE: goldilocks
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
1. Get the application URL by running these commands:
  kubectl -n goldilocks port-forward svc/goldilocks-dashboard 8080:80
  echo "Visit http://127.0.0.1:8080 to use your application"
```

---

## Step 4: Verify the Installation

### Check pods are Running

```bash
kubectl get pods -n goldilocks
```

Expected output:

```
NAME                                     READY   STATUS    RESTARTS   AGE
goldilocks-controller-6d65d5bfb9-gtpbv   1/1     Running   0          30s
goldilocks-dashboard-dcc5d9c8c-vcvvf     1/1     Running   0          30s
```

Both pods must show `1/1 Running` before continuing. If they show `ImagePullBackOff`, see the troubleshooting section below.

### Check services

```bash
kubectl get svc -n goldilocks
```

Expected output:

```
NAME                   TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
goldilocks-dashboard   ClusterIP   10.43.252.243   <none>        80/TCP    30s
```

### Confirm the correct image is being used

```bash
kubectl get pods -n goldilocks \
  -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'
```

Expected output:

```
goldilocks-controller-6d65d5bfb9-gtpbv   us-docker.pkg.dev/fairwinds-ops/oss/goldilocks:v4.15.1
goldilocks-dashboard-dcc5d9c8c-vcvvf     us-docker.pkg.dev/fairwinds-ops/oss/goldilocks:v4.15.1
```

Both pods must use the `us-docker.pkg.dev` registry.

### Verify with the built-in script

```bash
bash scripts/verify-goldilocks.sh
```

---

## Understanding the Two Components

### Controller

The controller watches for namespaces labeled with `goldilocks.fairwinds.com/enabled=true`. When it finds one, it:
- Creates a `VerticalPodAutoscaler` object for each `Deployment` in that namespace
- Names each VPA `goldilocks-<deployment-name>`
- Sets VPA update mode to `Off` (never evicts pods)
- Deletes the VPA if the deployment is removed or the label is removed

The controller does NOT watch `DaemonSet` or `StatefulSet` — only `Deployment`.

### Dashboard

The dashboard is a read-only web UI that:
- Lists all namespaces with the Goldilocks label
- For each namespace, shows each deployment's current resource requests/limits
- Displays VPA's `lowerBound`, `target`, and `upperBound` recommendations
- Generates copy-pasteable YAML patches in both Guaranteed and Burstable configurations

---

## Helm Chart Version Note

The Helm chart version and the app version are tracked separately:

| Chart Version | App Version |
|--------------|-------------|
| 10.4.0 | v4.14.1 (default) |

Our `values.yaml` overrides the app version to `v4.15.1` by specifying the `image.tag`. The chart is the same — only the image tag changes. This is a common pattern for pinning to patch releases when the chart hasn't been updated yet.

---

## Troubleshooting

### `ImagePullBackOff` on goldilocks pods

```bash
kubectl describe pod -n goldilocks -l app.kubernetes.io/name=goldilocks
# Look for: "Failed to pull image"
```

If you see an error referencing `quay.io/fairwinds/goldilocks`, your values override didn't apply. Check:

```bash
helm get values goldilocks -n goldilocks
```

Ensure `image.repository` and `image.tag` are set correctly.

### Controller pod running but no VPAs appear

This is expected — the controller only creates VPAs after you label a namespace. That step comes in Lesson 05.

### Dashboard returns "No namespaces found"

Same as above. The dashboard shows "no namespaces" until you label at least one namespace with `goldilocks.fairwinds.com/enabled=true`.

---

## Verification Checklist

```bash
# Both pods Running
kubectl get pods -n goldilocks

# Correct image registry
kubectl get pods -n goldilocks \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Both lines should start with: us-docker.pkg.dev/fairwinds-ops/oss/goldilocks

# Service exists
kubectl get svc goldilocks-dashboard -n goldilocks

# Helm release healthy
helm list -n goldilocks
# STATUS should be: deployed
```

---

## Practice on Killercoda

Want to try this in a browser without any local setup? The Killercoda lab for this lesson gives you a live Kubernetes cluster with Helm pre-installed — just follow the steps.

**[→ Open Lab 1/3: Install Goldilocks and VPA](https://killercoda.com/devoriales/course/goldilocks/scenario-1-install-goldilocks)**

The lab takes ~15 minutes and includes automated step verification.

---

## What's Next

In [Lesson 05](../05-enable-and-observe/), you'll label the `metrics-app` namespace to activate Goldilocks, watch it create VPA objects automatically, and see the first recommendations appear.
