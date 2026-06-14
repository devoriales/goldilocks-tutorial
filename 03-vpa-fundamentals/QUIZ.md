# Quiz — Lesson 03: VPA Fundamentals

## Question 1

**You want to collect VPA recommendations without any risk of pods being restarted. Which update mode should you use?**

- A. `Auto` — applies recommendations automatically without restarts
- B. `Initial` — only sets resources at pod creation time
- C. `Off` — calculates recommendations but never applies them
- D. `Recreate` — applies recommendations by gracefully restarting pods

## Question 2

**A VPA object's `lowerBound` for CPU is `17m` and `upperBound` is `19955m` after 2 minutes of data. Which value should you trust for setting resource requests?**

- A. `upperBound` — it represents the worst-case usage scenario
- B. `lowerBound` or `target` — these converge faster and are more reliable early on
- C. Neither — VPA recommendations are unreliable until the cluster is deleted and recreated
- D. `upperBound` — it's always the most accurate value

## Question 3

**Your VPA object targets a deployment named `api`, but the recommendation shows `Container Name: httpbin`. Why?**

- A. VPA made an error — it is targeting the wrong deployment
- B. VPA names containers by the deployment's selector labels, not the deployment name
- C. VPA tracks containers by `spec.containers[].name`, which is `httpbin` in the api deployment spec
- D. This happens when VPA is not properly configured with `targetRef`

## Question 4

**You enable both HPA (Horizontal Pod Autoscaler) and VPA in `Auto` mode on the same deployment. What happens?**

- A. They work together: HPA scales replicas, VPA scales resources per replica
- B. HPA takes priority; VPA recommendations are ignored
- C. They conflict — HPA and VPA Auto mode fight each other, causing erratic scaling behavior
- D. Kubernetes automatically resolves the conflict using priority classes

---

## Answers

| Question | Correct Answer | Explanation |
|----------|---------------|-------------|
| 1 | **C** | `Off` mode is purely advisory — VPA calculates recommendations and stores them in the VPA object's status, but never modifies any pod. This is what Goldilocks uses. It's the only mode that is completely safe to use on production workloads with no risk of disruption. |
| 2 | **B** | VPA's `upperBound` requires extensive historical data to converge. Early recommendations often show unrealistically high upper bounds (e.g., 24Gi memory for a container that uses 160Mi). The `lowerBound` and `target` converge much faster — they are based on observed usage, not projected worst-case. Use these for initial resource setting. |
| 3 | **C** | VPA's `targetRef` points to the deployment, but recommendations are reported per container within that deployment. The container name comes from `spec.template.spec.containers[].name` in the deployment manifest. In our case, the api deployment has a container named `httpbin` (the image name), which is what VPA reports. |
| 4 | **C** | HPA scales the number of replicas based on CPU/memory thresholds. VPA in Auto mode evicts pods and recreates them with new resource values. When both run simultaneously, VPA evicts a pod, HPA sees average CPU drop and scales down, VPA sees more load per pod and evicts again — an unstable loop. Use HPA for horizontal scaling and VPA `Off` mode (via Goldilocks) for recommendations only. |
