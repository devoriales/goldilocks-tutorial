# Quiz — Lesson 05: Enable and Observe

## Question 1

**What label do you add to a namespace to activate Goldilocks?**

- A. `app.kubernetes.io/managed-by=goldilocks`
- B. `goldilocks.fairwinds.com/enabled=true`
- C. `vpa.kubernetes.io/enabled=true`
- D. `fairwinds.com/goldilocks=enabled`

## Question 2

**You label the `payments` namespace and wait 5 minutes, but `kubectl get vpa -n payments` returns "No resources found." The Goldilocks controller pod is Running. What is the most likely cause?**

- A. VPA is not installed in the cluster
- B. The namespace has no Deployments — Goldilocks only creates VPAs for Deployments
- C. Goldilocks requires 10 minutes after labeling before creating VPAs
- D. The `payments` namespace needs a matching label on each Deployment

## Question 3

**After labeling a namespace, the VPA `PROVIDED` column shows `False` for several minutes. What should you do?**

- A. Delete and recreate the VPA objects — they failed to initialize
- B. Restart the VPA recommender pod
- C. Wait — VPA needs time to collect metrics data. `PROVIDED` becomes `True` when the first recommendation is available (usually within 60-90 seconds of pod metrics being available)
- D. Increase the metrics-server scrape interval

## Question 4

**You need resource recommendations for a StatefulSet named `postgres` in the `db` namespace. You label the namespace with `goldilocks.fairwinds.com/enabled=true`. After waiting, `kubectl get vpa -n db` shows nothing for postgres. Why?**

- A. Goldilocks requires a separate label on each StatefulSet
- B. The Goldilocks controller only creates VPAs for Deployments — StatefulSets are not supported
- C. StatefulSets require VPA in `Recreate` mode, which Goldilocks doesn't use
- D. StatefulSets with persistent volumes are excluded from VPA recommendations

---

## Answers

| Question | Correct Answer | Explanation |
|----------|---------------|-------------|
| 1 | **B** | The exact label is `goldilocks.fairwinds.com/enabled=true`. The key must be `goldilocks.fairwinds.com/enabled` and the value must be `"true"`. Any other label format will be ignored by the controller. |
| 2 | **B** | The Goldilocks controller only creates VPAs for `Deployment` objects. If a namespace has no Deployments (only StatefulSets, DaemonSets, or no workloads at all), the controller takes no action and `kubectl get vpa` returns nothing. For StatefulSets, create VPAs manually with `updateMode: "Off"`. |
| 3 | **C** | `PROVIDED: False` means VPA has created the object but hasn't computed a recommendation yet. This is normal immediately after labeling. The VPA recommender needs at least one round of metrics from metrics-server before it can produce estimates. Wait 60-90 seconds and check again. |
| 4 | **B** | The Goldilocks controller explicitly targets only `Deployment` resources when creating VPA objects. `StatefulSet`, `DaemonSet`, `Job`, and other workload types are not managed by Goldilocks. To get recommendations for a StatefulSet, create a `VerticalPodAutoscaler` object manually (as shown in Lesson 03) with `updateMode: "Off"`. |
