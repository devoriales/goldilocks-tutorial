# Tutorial Verification Checklist

Use this checklist to confirm each lesson completed successfully. Every checkbox corresponds to a command you can run to verify your state.

---

## Prerequisites

Before starting Lesson 02:

- [ ] Docker is running: `docker info | grep "Server Version"`
- [ ] k3d is installed: `k3d version`
- [ ] kubectl is installed: `kubectl version --client`
- [ ] Helm is installed: `helm version`

---

## Lesson 01 — The Resource Requests Problem

No cluster required for this lesson.

- [ ] Read the lesson content
- [ ] Completed the quiz

---

## Lesson 02 — Local Kubernetes Setup with k3d

- [ ] k3d cluster created: `k3d cluster list` (should show `goldilocks-demo`)
- [ ] Nodes ready: `kubectl get nodes` (all nodes STATUS = Ready)
- [ ] VPA CRDs installed: `kubectl get crd | grep autoscaling.k8s.io` (should show verticalpodautoscalers)
- [ ] VPA pods running: `kubectl get pods -n kube-system | grep vpa` (should show recommender, updater, admission-controller)
- [ ] metrics-server running: `kubectl get pods -n kube-system | grep metrics-server`
- [ ] Metrics available: `kubectl top nodes` (should show CPU/memory usage, not "unknown")

---

## Lesson 03 — VPA Fundamentals

- [ ] Sample app deployed: `kubectl get pods -n metrics-app` (all Running)
- [ ] Manual VPA created: `kubectl get vpa -n metrics-app` (shows `api-vpa-manual`)
- [ ] VPA recommendation appears: `kubectl describe vpa api-vpa-manual -n metrics-app | grep -A 5 "Recommendation"`

---

## Lesson 04 — Installing Goldilocks

- [ ] Goldilocks namespace exists: `kubectl get ns goldilocks`
- [ ] Controller pod running: `kubectl get pods -n goldilocks | grep controller`
- [ ] Dashboard pod running: `kubectl get pods -n goldilocks | grep dashboard`
- [ ] Both pods Ready 1/1:
  ```bash
  kubectl get pods -n goldilocks
  # Expected:
  # goldilocks-controller-...   1/1   Running
  # goldilocks-dashboard-...    1/1   Running
  ```

---

## Lesson 05 — Enabling Namespaces and Observing VPAs

- [ ] Namespace labeled: `kubectl get ns metrics-app --show-labels | grep goldilocks`
- [ ] VPAs created automatically:
  ```bash
  kubectl get vpa -n metrics-app
  # Expected: goldilocks-frontend, goldilocks-api, goldilocks-worker
  ```
- [ ] VPA targets correct deployment: `kubectl describe vpa goldilocks-frontend -n metrics-app | grep "Name:"`

---

## Lesson 06 — The Goldilocks Dashboard

- [ ] Port-forward running: `curl -s http://localhost:8080 | grep -c "goldilocks"` (returns > 0)
- [ ] Dashboard shows metrics-app namespace
- [ ] All 3 deployments visible (frontend, api, worker)
- [ ] Recommendation columns populated (not blank)

---

## Lesson 07 — Applying Recommendations

- [ ] Frontend resources updated: `kubectl describe deployment frontend -n metrics-app | grep -A 4 "Requests:"`
- [ ] Frontend rollout complete: `kubectl rollout status deployment/frontend -n metrics-app`
- [ ] Frontend QoS class is Guaranteed:
  ```bash
  kubectl get pod -n metrics-app -l app=frontend \
    -o jsonpath='{.items[0].status.qosClass}'
  # Expected: Guaranteed
  ```
- [ ] API QoS class is Burstable:
  ```bash
  kubectl get pod -n metrics-app -l app=api \
    -o jsonpath='{.items[0].status.qosClass}'
  # Expected: Burstable
  ```
- [ ] goldilocks summary produces valid JSON:
  ```bash
  kubectl exec -n goldilocks deploy/goldilocks-dashboard -- goldilocks summary | python3 -m json.tool > /dev/null && echo "Valid JSON"
  ```

---

## Lesson 08 — Advanced Configuration

- [ ] VPA resource policy annotation applied: `kubectl describe ns metrics-app | grep goldilocks`
- [ ] Goldilocks VPA reflects ContainerPolicies: `kubectl describe vpa goldilocks-api -n metrics-app | grep -A 8 "Container Policies"`

---

## Lesson 09 — Production Considerations

- [ ] Read the lesson content
- [ ] goldilocks summary JSON output reviewed

---

## Common Troubleshooting

### VPA objects not appearing after namespace label

```bash
# Check the label was applied
kubectl get ns metrics-app --show-labels

# Check Goldilocks controller logs
kubectl logs -n goldilocks -l app.kubernetes.io/component=controller --tail=30

# Force a reconcile by removing and re-adding the label
kubectl label ns metrics-app goldilocks.fairwinds.com/enabled-
kubectl label ns metrics-app goldilocks.fairwinds.com/enabled=true
```

### metrics-server shows "unknown" for kubectl top

```bash
# Verify metrics-server has --kubelet-insecure-tls
kubectl get deployment metrics-server -n kube-system -o yaml | grep kubelet-insecure-tls

# Check metrics API availability
kubectl get apiservice v1beta1.metrics.k8s.io -o yaml | grep "status" -A 5
```

### Goldilocks image pull fails

```bash
# Verify you are using the new registry path (not quay.io)
kubectl describe pod -n goldilocks -l app.kubernetes.io/name=goldilocks | grep "Image:"
# Must show: us-docker.pkg.dev/fairwinds-ops/oss/goldilocks:v4.15.1
```

### VPA recommendations look unrealistic (e.g., 100T memory)

This is normal for early recommendations. VPA needs approximately **8 days** of historical data for accurate upper bounds. Run the load generator and check back later. Lower bounds (`lowerBound`) converge faster.

### Cluster cleanup and restart

```bash
# Delete everything and start fresh
bash scripts/cleanup.sh

# Or manually:
k3d cluster delete goldilocks-demo
```

---

## FAQ

**Q: Do I need to complete lessons in order?**
A: Lessons 02-09 require an active cluster with the previous lesson's setup. Start at Lesson 02 and follow sequentially.

**Q: Can I use an existing Kubernetes cluster instead of k3d?**
A: Yes, but VPA and metrics-server installation will differ. The tutorial is written for k3d. For existing clusters, skip cluster creation in Lesson 02 and adapt the VPA installation to your environment.

**Q: Why does the dashboard show no recommendations for the first few minutes?**
A: VPA needs time to collect metrics from the metrics API. Wait 5-10 minutes after deploying the load generator before expecting meaningful recommendations.

**Q: What is the difference between Guaranteed and Burstable recommendations?**
A: See Lesson 06. Short answer: Guaranteed sets requests == limits (stable, predictable, costs more), Burstable sets requests < limits (efficient, allows bursting, may throttle).
