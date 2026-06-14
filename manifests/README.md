# Manifests

Supporting Kubernetes manifests for the Goldilocks tutorial.

## Apply Order

```
00-vpa/       → Install first (VPA CRDs must exist before Goldilocks)
01-goldilocks/ → Install second (Goldilocks Helm values)
02-recommendations/ → Reference only (before/after examples)
```

## 00-vpa

Instructions and reference for installing the Vertical Pod Autoscaler.
VPA is installed via Helm in this tutorial (not via these manifest files directly).
See `00-vpa/README.md` for the exact install commands.

## 01-goldilocks

Goldilocks Helm values file used in Lesson 04.

```bash
helm install goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  --version 10.4.0 \
  --values manifests/01-goldilocks/values.yaml
```

## 02-recommendations

Example deployment patches showing before/after resource settings. Used as reference in Lesson 07.
These are illustrative — apply your own values from the Goldilocks dashboard.
