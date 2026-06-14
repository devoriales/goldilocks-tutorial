# metrics-app — Sample Application

The `metrics-app` is a three-service demo application with **intentionally wrong resource settings** so Goldilocks can show interesting, varied recommendations.

## The Problem

| Service | Image | Misconfiguration | QoS Class | What Goldilocks Will Show |
|---------|-------|-----------------|-----------|--------------------------|
| `frontend` | nginx:alpine | **Over-provisioned** — requests 500m CPU / 512Mi memory, but actually uses ~2m / ~10Mi | Guaranteed | Recommends dramatic reduction (saves money) |
| `api` | kennethreitz/httpbin | **Under-provisioned requests** — requests 10m CPU / 32Mi memory, but actually uses ~50m / ~80Mi | Burstable | Recommends increasing requests (improves stability) |
| `worker` | python:3.11-alpine | **Mismatched** — low request (50m CPU / 32Mi) vs high limit (1000m CPU / 128Mi) | Burstable | Shows lowerBound vs upperBound divergence |
| `load-generator` | busybox | Sends HTTP requests to frontend and api every second | Best-effort-ish | Generates traffic so VPA has data |

## Why These Misconfigurations?

### Over-provisioned frontend

Kubernetes schedules pods based on **requests**, not limits. When frontend requests 500m CPU, the scheduler reserves that capacity on a node — even if nginx only uses 2m. At scale, this wastes money on node capacity that's never used.

VPA's Goldilocks recommendation for frontend will be much lower than what's currently requested. This demonstrates the cost savings opportunity.

### Under-provisioned api

httpbin (Python/Gunicorn) actually uses ~50m CPU and ~80Mi memory at steady state. With only 10m CPU requested:
- The kernel throttles the container aggressively via CFS scheduler
- Responses are slow even under light load — latency increases

With only 32Mi memory requested (vs ~80Mi actual usage):
- VPA will recommend higher memory requests to prevent scheduler eviction under pressure
- The memory limit (128Mi) is set high enough to avoid OOMKills while the tutorial runs

VPA will recommend significantly increasing both CPU and memory requests.

### Mismatched worker

The worker runs CPU-intensive computation in bursts (factorial calculations). It needs significant CPU during computation cycles but very little at rest. The current settings:
- Request (50m): too low for computation bursts
- Limit (1000m): excessive headroom

VPA's `lowerBound` (based on idle) and `upperBound` (based on spikes) will diverge significantly, showing learners why the Burstable QoS class is appropriate here.

## Deploying

```bash
# Deploy everything at once
bash scripts/deploy-sample-app.sh

# Or manually, in order:
kubectl apply -f sample-app/namespace.yaml
kubectl apply -f sample-app/frontend/
kubectl apply -f sample-app/api/
kubectl apply -f sample-app/worker/
kubectl apply -f sample-app/load-generator/

# Verify all pods are running
kubectl get pods -n metrics-app
```

## Important: Goldilocks Label

The namespace is created **without** the `goldilocks.fairwinds.com/enabled=true` label. Adding that label is the hands-on exercise in Lesson 05. Do not add it when first deploying the app.

## Expected Pod Status

After deployment (allow 2-3 minutes for images to pull):

```
NAME                              READY   STATUS    RESTARTS   AGE
api-...                           1/1     Running   0          2m
api-...                           1/1     Running   0          2m
frontend-...                      1/1     Running   0          2m
frontend-...                      1/1     Running   0          2m
load-generator-...                1/1     Running   0          2m
worker-...                        1/1     Running   0          2m
```

> ⚠️ The `api` pods (httpbin) may take 60-90 seconds to start due to Python/Gunicorn initialization. This is normal.
