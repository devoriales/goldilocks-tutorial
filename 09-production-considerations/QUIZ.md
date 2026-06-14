# Quiz — Lesson 09: Production Considerations

## Question 1

**A VPA object was created 6 hours ago. The dashboard shows a Burstable recommendation with a CPU limit of `48000m`. Should you apply this limit?**

- A. Yes — Goldilocks generates safe limits regardless of data age
- B. No — the `upperBound` used for Burstable limits requires ~8 days to converge; after 6 hours it is wildly inflated. Set limits manually at 2–3× the `target` value instead
- C. Yes — a high limit is conservative and therefore always safer
- D. No — Burstable QoS should never be used in production

## Question 2

**Your e-commerce platform has a Deployment that handles 10× normal traffic every Saturday. VPA has been running for 10 days, but the data window covered only one Saturday. The recommendation looks low. What should you do?**

- A. Trust the recommendation — 10 days is well within the 8-day convergence window
- B. The recommendation may underestimate Saturday peak. Add a buffer above the VPA `target` based on your historical peak-to-average ratio, and monitor closely on the next Saturday after applying
- C. Disable Goldilocks for this deployment — seasonal workloads are not supported
- D. Switch to VPA `Auto` mode so it can adjust automatically during the Saturday spike

## Question 3

**You want to integrate Goldilocks into a GitOps pipeline so that out-of-date resource settings automatically open a PR. What is the correct data source for this automation?**

- A. The Goldilocks dashboard HTML — scrape the web UI for recommendation values
- B. The VPA object's `.status.recommendation.containerRecommendations` field via the Kubernetes API — this is the authoritative machine-readable source
- C. The Goldilocks controller logs — it emits recommendation events you can parse
- D. The metrics-server API — you can calculate optimal values directly from live usage

## Question 4

**A JVM application (`java -jar app.jar`) uses 2 Gi of memory at startup and drops to 512Mi at steady state. VPA has been running for 14 days and recommends `512Mi`. If you apply `requests: 512Mi, limits: 512Mi` (Guaranteed), what will happen?**

- A. The pod starts successfully — JVM's memory usage at startup doesn't count toward the limit
- B. The pod will likely be OOMKilled during startup — JVM memory usage peaks well above 512Mi during class loading and JIT compilation, exceeding the limit before steady state is reached
- C. The pod starts fine — Kubernetes allows 10% burst above the limit at startup
- D. The pod will be throttled during startup, then run normally — this is expected Guaranteed behavior

---

## Answers

| Question | Correct Answer | Explanation |
|----------|---------------|-------------|
| 1 | **B** | The `upperBound` used for Burstable limits is computed by VPA using a statistical model that requires a full week of data to capture the natural usage distribution. At 6 hours, VPA has seen a tiny fraction of the pod's lifecycle and projects worst-case values that are orders of magnitude above actual peak usage. The `target` is more reliable sooner, but even that should be treated cautiously in the first 24 hours. Set limits at 2–3× the `target` as a safe starting point until you have mature data. |
| 2 | **B** | VPA models usage based on what it observed. If the Saturday spike represents a 10× increase and VPA has only one Saturday data point, the distribution is skewed toward weekday usage. The recommendation for requests may be accurate for normal traffic but insufficient for peak. Calculate a multiplier (e.g., if Saturday CPU is 10× average weekday, and VPA recommends 50m, your Saturday-safe value is ~500m). Add a buffer and monitor the next Saturday. This is a case where domain knowledge must supplement VPA data. |
| 3 | **B** | The `.status.recommendation.containerRecommendations` field on each VPA object is the canonical machine-readable source. It contains `lowerBound`, `target`, `uncappedTarget`, and `upperBound` in structured JSON/YAML. Scripts can query this with `kubectl get vpa -o json` and process with jq or Python. Scraping the dashboard HTML is fragile (UI can change), and log parsing is unreliable. |
| 4 | **B** | JVM startup is resource-intensive: class loading, JIT compilation, and heap initialization can temporarily use 2–4× the steady-state memory. If the memory limit is set to `512Mi` (the steady-state value), the kernel will send OOMKill to the process as soon as it exceeds that limit during startup — before the app ever serves a request. For JVM workloads, always add a startup buffer: either set limits to the observed startup peak (e.g., 2Gi), or use `Burstable` QoS with a higher limit and lower request. |
