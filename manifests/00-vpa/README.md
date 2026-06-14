# Installing VPA (Vertical Pod Autoscaler)

The VPA must be installed **before** Goldilocks. Goldilocks creates VPA objects — if the VPA CRDs don't exist, those creates will fail.

## Method: Helm (Recommended)

This tutorial uses the `fairwinds-stable/vpa` Helm chart:

```bash
helm repo add fairwinds-stable https://charts.fairwinds.com/stable
helm repo update

kubectl create namespace vpa

helm install vpa fairwinds-stable/vpa \
  --namespace vpa \
  --version 4.12.0 \
  --wait \
  --timeout 180s
```

**Chart details:**
- Chart version: 4.12.0
- App version (VPA): 1.6.0
- Components installed: recommender, updater, admission-controller
- Namespace: `vpa`

## Verify

```bash
# All three VPA pods should be Running
kubectl get pods -n vpa

# VPA CRDs should be present
kubectl get crd | grep autoscaling.k8s.io
# Expected:
# verticalpodautoscalercheckpoints.autoscaling.k8s.io
# verticalpodautoscalers.autoscaling.k8s.io
```

## Automated Setup

The `scripts/setup-cluster.sh` script handles VPA installation automatically.

## Why Use the Fairwinds Helm Chart?

The VPA project (kubernetes/autoscaler) provides install scripts, but they require cloning the entire autoscaler repository. The Fairwinds chart is:
- Version-pinnable (reproducible installs)
- Helm lifecycle managed (easy upgrade/uninstall)
- Pre-configured with sensible defaults for the admission controller webhook
