# Right-Sizing Kubernetes: A Practical Goldilocks Tutorial

> A hands-on, 9-lesson tutorial for Kubernetes administrators who want data-driven resource recommendations — not guesswork.

---

## Overview

Kubernetes resource requests and limits are deceptively difficult to tune. Set them too high and you waste money on unused capacity. Set them too low and you get OOMKills, CPU throttling, and unstable workloads. Most teams resort to guessing.

**Goldilocks** is an open-source tool by [Fairwinds](https://www.fairwinds.com/) that uses the Vertical Pod Autoscaler (VPA) to analyze your running workloads and recommend resource values that are — just right.

This tutorial series walks you through a complete Goldilocks setup on a local Kubernetes cluster, from understanding the problem to applying recommendations and configuring advanced options.

### Who Is This For?

- Kubernetes administrators managing cluster costs and stability
- DevOps engineers tired of guessing resource values
- Platform engineers who want to implement a systematic resource optimization workflow

### Prerequisites

- **macOS or Linux** with [Docker](https://www.docker.com/) running
- Basic familiarity with Kubernetes: Deployments, Services, `kubectl`
- No prior knowledge of VPA or Goldilocks required

---

## The Scenario

> *Your team runs the **metrics platform** on Kubernetes. The frontend is hemorrhaging cluster capacity — it's requesting 500m CPU it never uses. The API service is crashing under load — it only gets 10m CPU. And nobody knows what the worker actually needs. Leadership wants costs down and stability up. Enter Goldilocks.*

Throughout these lessons you will:

1. **Understand** why resource misconfiguration is expensive and dangerous
2. **Build** a local k3d cluster with VPA and metrics-server installed
3. **Learn** VPA fundamentals before automating with Goldilocks
4. **Install** Goldilocks via Helm using the latest registry
5. **Enable** namespace monitoring and watch VPA objects appear automatically
6. **Read** the Goldilocks dashboard and understand Guaranteed vs Burstable recommendations
7. **Apply** recommendations and verify QoS class changes
8. **Configure** advanced options: container exclusions, VPA bounds, on-by-default mode
9. **Plan** for production: the 8-day convergence window, CI/CD integration, and multi-namespace strategy

---

## Lesson Index

| Lesson | Title | Duration | Topics |
|--------|-------|----------|--------|
| 01 | [The Resource Requests Problem](01-intro-resource-problem/) | ~10 min | OOMKills, CPU throttling, QoS classes, cost implications |
| 02 | [Local Kubernetes Setup with k3d](02-local-k8s-setup/) | ~20 min | k3d, VPA CRDs, metrics-server |
| 03 | [VPA Fundamentals](03-vpa-fundamentals/) | ~15 min | VPA modes, manual VPA objects, reading raw recommendations |
| 04 | [Installing Goldilocks](04-install-goldilocks/) | ~15 min | Helm install, new registry path, architecture overview |
| 05 | [Enabling Namespaces and Observing VPAs](05-enable-and-observe/) | ~15 min | Namespace label, automatic VPA creation, controller logs |
| 06 | [The Goldilocks Dashboard](06-goldilocks-dashboard/) | ~20 min | Port-forward, reading columns, Guaranteed vs Burstable |
| 07 | [Applying Recommendations](07-applying-recommendations/) | ~20 min | kubectl set resources, QoS verification, goldilocks summary |
| 08 | [Advanced Configuration](08-advanced-configuration/) | ~15 min | Container exclusions, VPA bounds, on-by-default |
| 09 | [Production Considerations](09-production-considerations/) | ~15 min | 8-day convergence, CI/CD, multi-namespace |

**Reference:** [Goldilocks Cheatsheet](goldilocks-cheatsheet/) — all commands and configuration options in one place

---

## Getting Started

### System Requirements

| Requirement | Details |
|-------------|---------|
| OS | macOS or Linux |
| Docker | Running with at least 4 GB memory allocated |
| Disk space | ~2 GB for container images |
| Tools | k3d, kubectl, helm (installed in Lesson 02) |

### Estimated Time

The full series takes approximately **2.5 to 3 hours**. Each lesson is short and focused (~10-20 min). Lessons 02-09 require a running k3d cluster — set it up once in Lesson 02 and keep it for the series.

### Quick Start

```bash
# Automated cluster setup (after installing k3d, kubectl, helm)
bash scripts/setup-cluster.sh

# Or serve any lesson locally
npx serve 01-intro-resource-problem
# Then open http://localhost:3000
```

---

## Tech Stack

| Tool | Version | Purpose |
|------|---------|---------|
| k3d | v5.x | Local k3s-in-Docker cluster |
| Kubernetes | v1.31+ | Via k3s inside k3d |
| Goldilocks | v4.15.1 | Resource recommendation dashboard |
| Goldilocks Helm chart | 10.4.0 | Installation via Helm |
| VPA (kubernetes/autoscaler) | latest | Underlying recommendation engine |
| metrics-server | latest | Node/pod metrics for VPA |
| Helm | v3.10+ | Package manager |

---

## Legend

- 🎯 **Goldilocks-managed** — resource or object created/managed by Goldilocks
- ⚠️ **Common pitfall** — mistakes learners frequently make
- ✅ **Verified working** — tested command or configuration
- 💡 **Best practice** — recommended approach for production

---

## Additional Resources

- [Goldilocks Cheatsheet](goldilocks-cheatsheet/) — quick reference card
- [Goldilocks Documentation](https://goldilocks.docs.fairwinds.com/)
- [Goldilocks GitHub](https://github.com/FairwindsOps/goldilocks)
- [Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)
- [Kubernetes QoS Classes](https://kubernetes.io/docs/concepts/workloads/pods/pod-qos/)
- [Fairwinds Blog: Introducing Goldilocks](https://www.fairwinds.com/blog/introducing-goldilocks-a-tool-for-recommending-resource-requests)
