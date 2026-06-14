# Lesson 01: Local Kubernetes Setup with k3d

> **Duration**: ~20 minutes | **Level**: Beginner | [← All Lessons](../) | [Next →](../02-intro-resource-problem/)

## Overview

In this lesson you'll build the local Kubernetes environment that the rest of the tutorial runs on. By the end, you'll have:

- A 3-node k3d cluster named `goldilocks-demo`
- VPA (Vertical Pod Autoscaler) installed and running
- metrics-server installed and serving node/pod metrics

> 💡 **Shortcut**: Run `bash scripts/setup-cluster.sh` to do all of this automatically. Follow the manual steps below to understand what each command does.

---

## Learning Objectives

- Install k3d, kubectl, and Helm on macOS or Linux
- Create a multi-node k3d cluster
- Understand why VPA and metrics-server are prerequisites for Goldilocks
- Verify the environment is ready before proceeding

---

## Clone the Tutorial Repository

All sample app manifests, Helm values, and helper scripts live in the companion GitHub repo. Clone it first:

```bash
git clone https://github.com/devoriales/goldilocks-tutorial.git
cd goldilocks-tutorial
```

You'll run commands from this directory throughout the tutorial.

---

## Prerequisites

- Docker Desktop running (4 GB+ memory allocated)
- macOS with Homebrew, or Linux with apt/yum
- Internet access to pull container images

---

## Step 1: Install the Tools

### macOS (Homebrew)

```bash
brew install k3d kubectl helm
```

### Linux (manual)

```bash
# k3d
curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

Verify installations:

```bash
k3d version          # Should show v5.x.x
kubectl version --client  # Should show v1.28+
helm version         # Should show v3.10+
```

---

## Step 2: Create the k3d Cluster

```bash
k3d cluster create goldilocks-demo \
  --agents 2 \
  --timeout 120s \
  --k3s-arg '--disable=metrics-server@server:0'
```

**What each flag does:**
- `--agents 2` — creates 1 server node + 2 agent nodes (3 total)
- `--timeout 120s` — fails cleanly if cluster doesn't start within 2 minutes
- `--k3s-arg '--disable=metrics-server@server:0'` — disables k3s's bundled metrics-server so we can install the official version via Helm

> ⚠️ **Why disable the built-in metrics-server?** k3s ships with a metrics-server that uses a Rancher-mirrored image (`rancher/mirrored-metrics-server`). On some Docker Desktop setups this image fails to pull due to disk space. We install `registry.k8s.io/metrics-server` via Helm instead — same functionality, different image source.

Verify nodes are ready:

```bash
kubectl get nodes
```

Expected output:

```
NAME                           STATUS   ROLES                  AGE   VERSION
k3d-goldilocks-demo-agent-0    Ready    <none>                 30s   v1.31.5+k3s1
k3d-goldilocks-demo-agent-1    Ready    <none>                 30s   v1.31.5+k3s1
k3d-goldilocks-demo-server-0   Ready    control-plane,master   35s   v1.31.5+k3s1
```

---

## Step 3: Install metrics-server

VPA needs the Kubernetes Metrics API to read CPU and memory usage from running pods. metrics-server provides this API.

```bash
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update metrics-server

helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set 'args[0]=--kubelet-insecure-tls' \
  --wait \
  --timeout 120s
```

> ⚠️ **Why `--kubelet-insecure-tls`?** k3d uses self-signed certificates for the kubelet API. metrics-server attempts to verify these certificates by default and fails. This flag skips TLS verification. It is safe in a local development cluster — do not use in production.

> ⚠️ **zsh users**: The single quotes around `'args[0]=--kubelet-insecure-tls'` are required. Without them, zsh treats `[0]` as an array subscript and the command fails.

Verify metrics-server is working:

```bash
kubectl top nodes
```

Expected output (values will differ):

```
NAME                           CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
k3d-goldilocks-demo-agent-0    168m         4%     204Mi           3%
k3d-goldilocks-demo-agent-1    116m         2%     151Mi           2%
k3d-goldilocks-demo-server-0   315m         7%     607Mi           10%
```

If you see `error: Metrics API not available`, wait 30 seconds and try again. metrics-server takes a moment to register its API service.

---

## Step 4: Install VPA

The Vertical Pod Autoscaler is the engine behind Goldilocks. It watches running pods, collects resource usage data, and generates recommendations. Goldilocks reads those recommendations and displays them in a dashboard.

```bash
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo update fairwinds-stable

kubectl create namespace vpa

helm install vpa fairwinds-stable/vpa \
  --namespace vpa \
  --version 4.12.0 \
  --wait \
  --timeout 180s
```

**What gets installed:**

| Component | Role |
|-----------|------|
| `vpa-recommender` | Reads metrics history, calculates resource recommendations |
| `vpa-updater` | Optionally applies recommendations by evicting pods (we use Off mode) |
| `vpa-admission-controller` | Intercepts pod creation to set initial resources (when in Initial mode) |

Verify all three VPA pods are running:

```bash
kubectl get pods -n vpa
```

Expected output:

```
NAME                                        READY   STATUS    RESTARTS   AGE
vpa-admission-controller-66548ff79f-bb57h   1/1     Running   0          60s
vpa-recommender-8595cf5fb7-sgwd5            1/1     Running   0          60s
vpa-updater-58ff9cff9b-68cwp                1/1     Running   0          60s
```

Verify VPA CRDs are registered:

```bash
kubectl get crd | grep autoscaling.k8s.io
```

Expected output:

```
verticalpodautoscalercheckpoints.autoscaling.k8s.io   2026-06-14T...
verticalpodautoscalers.autoscaling.k8s.io             2026-06-14T...
```

---

## Verification

Run the full verification script:

```bash
bash scripts/verify-prerequisites.sh
```

Or check manually:

```bash
# Cluster running
k3d cluster list
# → goldilocks-demo

# All nodes Ready
kubectl get nodes

# VPA pods Running
kubectl get pods -n vpa

# VPA CRDs exist
kubectl get crd | grep autoscaling.k8s.io

# metrics working
kubectl top nodes
```

All checks should pass before continuing to Lesson 03. ✅

---

## Tech Stack Summary

| Tool | Version | Namespace |
|------|---------|-----------|
| k3d | v5.8.x | — |
| Kubernetes | v1.31.5 | — |
| metrics-server | v0.8.1 | kube-system |
| VPA | v1.6.0 | vpa |

---

## What's Next

In [Lesson 03](../03-vpa-fundamentals/), you'll learn how VPA works by creating a manual VPA object for the metrics-app and reading raw recommendations — before Goldilocks simplifies the process.
