# Goldilocks Cheatsheet

> Quick reference for every command and pattern in this tutorial. | [← Lesson 09](../09-production-considerations/)

---

## Cluster Setup

```bash
# Create k3d cluster (disable built-in metrics-server)
k3d cluster create goldilocks-demo \
  --agents 2 --timeout 120s \
  --k3s-arg '--disable=metrics-server@server:0'

# Install metrics-server (single quotes required in zsh)
helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set 'args[0]=--kubelet-insecure-tls' \
  --wait --timeout 120s

# Install VPA
kubectl create namespace vpa
helm install vpa fairwinds-stable/vpa \
  --namespace vpa --version 4.12.0 \
  --wait --timeout 180s

# Verify
kubectl get nodes
kubectl get pods -n vpa
kubectl top nodes
```

---

## Install Goldilocks

```bash
# Create namespace
kubectl create namespace goldilocks

# Install (critical: use us-docker.pkg.dev registry, not quay.io)
helm install goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  --version 10.4.0 \
  -f manifests/01-goldilocks/values.yaml \
  --wait --timeout 180s

# Verify
kubectl get pods -n goldilocks
# Both goldilocks-controller and goldilocks-dashboard must be Running

# Confirm correct image registry
kubectl get pods -n goldilocks \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}'
# Must show: us-docker.pkg.dev/fairwinds-ops/oss/goldilocks:v4.15.1
```

**Required `values.yaml`:**
```yaml
image:
  repository: us-docker.pkg.dev/fairwinds-ops/oss/goldilocks
  tag: v4.15.1
vpa:
  enabled: false
metrics-server:
  enabled: false
```

---

## Enable a Namespace

```bash
# Activate Goldilocks for a namespace
kubectl label namespace <ns> goldilocks.fairwinds.com/enabled=true

# Confirm label applied
kubectl get namespace <ns> --show-labels

# Watch VPA objects appear (within ~10 seconds)
kubectl get vpa -n <ns> --watch

# Deactivate (removes Goldilocks-managed VPAs)
kubectl label namespace <ns> goldilocks.fairwinds.com/enabled-
```

---

## Read Recommendations

```bash
# Summary table (all VPAs in namespace)
kubectl get vpa -n <ns>
# Columns: NAME  MODE  CPU  MEM  PROVIDED  AGE

# Full recommendation detail
kubectl describe vpa goldilocks-<deployment> -n <ns>
# Look for: Recommendation → Container Recommendations

# Machine-readable: target CPU and memory for first container
kubectl get vpa goldilocks-<deployment> -n <ns> \
  -o jsonpath='{.status.recommendation.containerRecommendations[0].target}'

# All recommendations as structured output
kubectl get vpa -n <ns> -o json | \
  python3 -c "
import json, sys
vpas = json.load(sys.stdin)
for vpa in vpas['items']:
    name = vpa['metadata']['name'].replace('goldilocks-', '')
    recs = vpa.get('status', {}).get('recommendation', {}).get('containerRecommendations', [])
    for r in recs:
        print(f'{name}/{r[\"containerName\"]}: target={r[\"target\"]}')
"
```

---

## Open the Dashboard

```bash
kubectl -n goldilocks port-forward svc/goldilocks-dashboard 8080:80
# Open: http://localhost:8080
```

Dashboard URLs:
- Namespace list: `http://localhost:8080/namespaces`
- Namespace detail: `http://localhost:8080/dashboard/<namespace>`

---

## Manual VPA (Off Mode)

For StatefulSets, DaemonSets, or any workload Goldilocks doesn't cover:

```bash
kubectl apply -f - <<'EOF'
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-vpa
  namespace: <ns>
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment      # or StatefulSet, DaemonSet
    name: <deployment>
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

---

## Apply Recommendations

**Guaranteed QoS** (requests = limits = VPA target):
```bash
kubectl patch deployment <name> -n <ns> --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"<target-cpu>"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"<target-mem>"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"<target-cpu>"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"<target-mem>"}
]'
```

**Burstable QoS** (requests = lowerBound, limits = 2–3× target):
```bash
kubectl patch deployment <name> -n <ns> --type='json' -p='[
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/cpu","value":"<lower-cpu>"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/requests/memory","value":"<lower-mem>"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/cpu","value":"<2x-target-cpu>"},
  {"op":"replace","path":"/spec/template/spec/containers/0/resources/limits/memory","value":"<2x-target-mem>"}
]'
```

**Watch rollout and verify:**
```bash
kubectl rollout status deployment/<name> -n <ns>
kubectl get pod -n <ns> -l app=<name> \
  -o jsonpath='{.items[0].status.qosClass}'
# Expected: Guaranteed or Burstable

# Rollback if needed
kubectl rollout undo deployment/<name> -n <ns>
```

---

## Advanced Configuration

```bash
# On-by-default mode (cover all namespaces, with exclusions)
helm upgrade goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  -f manifests/01-goldilocks/values.yaml \
  --set 'controller.flags.on-by-default=true' \
  --set-string 'controller.flags.exclude-namespaces=kube-system'

# Hide sidecar containers from dashboard
helm upgrade goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  -f manifests/01-goldilocks/values.yaml \
  --set 'dashboard.excludeContainers=linkerd-proxy,istio-proxy'

# Ignore a controller kind cluster-wide
helm upgrade goldilocks fairwinds-stable/goldilocks \
  --namespace goldilocks \
  -f manifests/01-goldilocks/values.yaml \
  --set 'controller.flags.ignore-controller-kind=DaemonSet'

# Verify active controller flags
kubectl describe deployment goldilocks-controller -n goldilocks | grep -A 10 "Command:"
```

---

## Cluster Teardown

```bash
bash scripts/cleanup.sh
# Or directly:
k3d cluster delete goldilocks-demo
```

---

## QoS Class Reference

| Class | Condition | Eviction priority |
|-------|-----------|------------------|
| `Guaranteed` | requests == limits (all containers) | Last evicted |
| `Burstable` | requests < limits, or only some set | Middle |
| `BestEffort` | no requests or limits at all | First evicted |

Check a pod's QoS class:
```bash
kubectl get pod <pod> -n <ns> -o jsonpath='{.status.qosClass}'
```

---

## VPA Recommendation Fields

| Field | Use for |
|-------|---------|
| `lowerBound` | Burstable `requests` (minimum safe) |
| `target` | Guaranteed `requests` and `limits`; Burstable baseline |
| `uncappedTarget` | Diagnostic — same as target without min/max policy |
| `upperBound` | Burstable `limits` **after 8+ days of data only** |

---

## Common Pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| `ImagePullBackOff` on Goldilocks pods | Using deprecated `quay.io` registry | Set `image.repository: us-docker.pkg.dev/fairwinds-ops/oss/goldilocks` |
| No VPAs appear after labeling | No Deployments in namespace; or Goldilocks controller not running | Check `kubectl get pods -n goldilocks` |
| `PROVIDED: False` stays forever | VPA recommender can't reach metrics-server | Check `kubectl top pods -n <ns>` works |
| metrics-server install fails (ServiceAccount conflict) | k3s bundled metrics-server still running | Recreate cluster with `--k3s-arg '--disable=metrics-server@server:0'` |
| `kubectl top nodes` fails after metrics-server install | API registration takes ~30s | Wait and retry |
| VPA upperBound is unrealistically large | < 8 days of data | Use `target` for requests; set limits manually at 2–3× target |
| `zsh: no matches found: args[0]` | zsh treats `[0]` as array subscript | Use single quotes: `--set 'args[0]=--kubelet-insecure-tls'` |
