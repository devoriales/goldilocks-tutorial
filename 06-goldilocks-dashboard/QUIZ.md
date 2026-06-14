# Quiz — Lesson 06: The Goldilocks Dashboard

## Question 1

**The Goldilocks dashboard shows a `>` icon next to your CPU request for a deployment. What does this mean?**

- A. The recommended CPU is greater than your current setting — you are under-provisioned
- B. Your current CPU request is greater than the recommended value — you are over-provisioned
- C. The recommendation is not yet available — VPA is still collecting data
- D. Your CPU limit is greater than your CPU request — the pod is in Burstable QoS

## Question 2

**You copy the Burstable YAML from the dashboard for a pod that has only been running for 2 hours. The CPU limit shown is `45000m`. Should you use this value?**

- A. Yes — the dashboard always shows production-ready values
- B. No — VPA's `upperBound` needs ~8 days of data to converge; 45000m is unrealistically high for most workloads. Set limits based on your knowledge of the workload instead
- C. Yes, but divide by 2 to account for early data uncertainty
- D. No — limits should always equal requests (Guaranteed QoS only)

## Question 3

**What is the difference between the Guaranteed and Burstable YAML snippets the dashboard generates?**

- A. Guaranteed sets both requests and limits to the VPA `target`; Burstable sets requests to `lowerBound` and limits to `upperBound`
- B. Guaranteed uses VPA's `upperBound` for safety; Burstable uses the `target` for efficiency
- C. They are identical — the QoS class is determined by the scheduler, not the YAML
- D. Guaranteed removes all limits; Burstable sets requests equal to limits

## Question 4

**You navigate to `http://localhost:8080/namespaces` and see no namespaces listed. Goldilocks pods are Running. What is most likely wrong?**

- A. The dashboard requires a license key to show namespace data
- B. The port-forward is pointed at the wrong service port
- C. No namespace has been labeled with `goldilocks.fairwinds.com/enabled=true`
- D. The Goldilocks controller is not connected to VPA

---

## Answers

| Question | Correct Answer | Explanation |
|----------|---------------|-------------|
| 1 | **B** | The `>` icon means your current value is greater than the recommendation — you are over-provisioned. The `<` icon means the opposite (under-provisioned). Both icons appear in a warning color because both states represent misconfiguration: over-provisioning wastes money, under-provisioning causes throttling or OOMKills. |
| 2 | **B** | VPA's `upperBound` computation requires a distribution of historical usage data. In the first hours or days, the upper bound is wildly inflated because VPA has seen only a small sample of usage and projects worst-case scenarios. The `lowerBound` and `target` converge much faster. When using Burstable mode, use your own judgment for the limit — a reasonable rule of thumb is 2-3× the `target`, not the `upperBound`. |
| 3 | **A** | Guaranteed QoS sets `requests == limits == VPA target`, giving the pod a fixed allocation. Burstable QoS sets `requests = VPA lowerBound` (minimum safe) and `limits = VPA upperBound` (maximum observed), allowing the pod to burst when resources are free. The Kubernetes scheduler assigns the QoS class based on whether requests equal limits — it's determined by the values in the spec, not a separate field. |
| 4 | **C** | The Goldilocks dashboard only shows namespaces that have the `goldilocks.fairwinds.com/enabled=true` label. If no namespace has this label, the controller has created no VPA objects, and the dashboard has nothing to display. The fix is to label at least one namespace: `kubectl label namespace <name> goldilocks.fairwinds.com/enabled=true`. |
