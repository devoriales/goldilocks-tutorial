# Quiz — Lesson 07: Applying Recommendations

## Question 1

**You apply Goldilocks's Guaranteed recommendation to your nginx deployment, reducing memory from `512Mi` to `100Mi`. Within 5 minutes all pods restart with `OOMKilled`. What happened, and what should you do?**

- A. Goldilocks made an error — it always recommends too little memory
- B. VPA's recommendation was based on traffic at the time, which may not represent peak load. Roll back with `kubectl rollout undo` and reduce more gradually, or wait for 8+ days of data before applying memory reductions
- C. OOMKilled means the memory request is too low — increase only the request, not the limit
- D. nginx requires at least 256Mi — the recommendation is incorrect for this image

## Question 2

**You apply Burstable QoS with `requests: 19m CPU` and `limits: 9658m CPU` (copied directly from the dashboard's Burstable section after 3 hours of data). What is the risk?**

- A. No risk — the limit is just a ceiling and won't affect normal operation
- B. The limit is so high it provides no meaningful protection against CPU runaway processes; a bug or spike could consume 9+ CPUs and starve other pods on the same node
- C. Kubernetes will reject limits above 8 cores per container
- D. The pod will be evicted immediately because the limit exceeds node capacity

## Question 3

**What happens to a deployment's resources if the VPA recommendation changes after you've already patched the deployment (Goldilocks is in `Off` mode)?**

- A. Goldilocks automatically updates your deployment with the new recommendation
- B. Nothing — Goldilocks `Off` mode only reads; you must manually re-read the dashboard and apply any new values
- C. The pod is evicted and restarted with the new VPA recommendation
- D. A Kubernetes Event is created warning you that your values are out of date

## Question 4

**You want to apply recommendations to a StatefulSet. You open the Goldilocks dashboard, but the StatefulSet doesn't appear. What do you do?**

- A. Add the StatefulSet to the `goldilocks.fairwinds.com/enabled` annotation on the workload itself
- B. Create a VPA object manually with `updateMode: "Off"` targeting the StatefulSet, then read `kubectl describe vpa` for recommendations
- C. Goldilocks supports StatefulSets — check whether the namespace label is applied
- D. Enable VPA `Auto` mode for StatefulSets since `Off` mode doesn't support them

---

## Answers

| Question | Correct Answer | Explanation |
|----------|---------------|-------------|
| 1 | **B** | VPA recommendations are based on observed historical usage. If the nginx deployment had low traffic during the observation window, the `100Mi` recommendation may be accurate for that load but insufficient for peak traffic. The correct response is to roll back (`kubectl rollout undo`), then either wait for more data or apply reductions more conservatively. For memory specifically, reduce in steps (e.g., 512Mi → 300Mi → 150Mi → 100Mi) with monitoring between each step. |
| 2 | **B** | Setting a CPU limit of `9658m` (nearly 10 cores) for a single container is effectively no limit on most nodes. The limit exists to prevent one container from starving others. Using an unconverged `upperBound` as a real limit defeats this purpose. The better approach is to set limits to 2-3× the `target` value until you have sufficient historical data for the `upperBound` to converge (approximately 8 days). |
| 3 | **B** | Goldilocks always operates in `Off` mode — it observes and recommends, never applies. Once you've patched a deployment, Goldilocks continues updating the underlying VPA object with new data, but your deployment's resources stay at whatever you set until you manually apply a new patch. This is by design: you own the resource values in your manifests. |
| 4 | **B** | The Goldilocks controller only targets `Deployment` resources. For StatefulSets, the manual approach from Lesson 03 applies: create a `VerticalPodAutoscaler` object with `updateMode: "Off"` targeting the StatefulSet via `targetRef`, wait for recommendations to appear, and read them via `kubectl describe vpa`. |
