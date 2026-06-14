# Quiz — Lesson 08: Advanced Configuration

## Question 1

**You enable `on-by-default: true` on your cluster but forget to set `exclude-namespaces`. What happens?**

- A. Nothing — `on-by-default` only affects unlabeled namespaces, and system namespaces have no workloads
- B. Goldilocks creates VPA objects for Deployments in system namespaces like `kube-system`, adding noise to the dashboard and unnecessary load on the VPA recommender
- C. The controller crashes — `on-by-default` requires `exclude-namespaces` to be set
- D. VPA recommender starts evicting pods in system namespaces to apply recommendations

## Question 2

**You want to exclude the `load-generator` Deployment from Goldilocks recommendations while keeping all other Deployments in the same namespace active. How do you do this in Goldilocks v4.15.x?**

- A. Add annotation `goldilocks.fairwinds.com/enabled=false` to the Deployment
- B. Add label `goldilocks.fairwinds.com/enabled=false` to the Deployment
- C. This is not directly supported — you must either move the deployment to a separate namespace or delete its Goldilocks-created VPA manually (Goldilocks will recreate it)
- D. Set `controller.flags.ignore-deployments=load-generator` in Helm values

## Question 3

**You add a `resourcePolicy.containerPolicies[].minAllowed` to a VPA object created by Goldilocks. 45 seconds later the `minAllowed` is gone. Why?**

- A. VPA deleted it — `minAllowed` is not supported on VPAs in `Off` mode
- B. The Goldilocks controller reconciled the VPA and overwrote your manual edit, since it manages the VPA object's spec
- C. Kubernetes garbage-collects VPA resource policies after 30 seconds
- D. You must set `minAllowed` on the VPA admission controller, not the VPA object

## Question 4

**Your cluster uses Istio. Every pod has a `istio-proxy` sidecar. The Goldilocks dashboard shows two recommendation rows per deployment — one for your app container and one for `istio-proxy`. How do you hide the sidecar recommendations?**

- A. Add `istio-proxy` to `controller.flags.ignore-controller-kind`
- B. Label each pod with `goldilocks.fairwinds.com/exclude-containers=istio-proxy`
- C. Set `dashboard.excludeContainers=istio-proxy` in Helm values — this filters the container from the dashboard UI
- D. This is not configurable — Goldilocks always shows all containers

---

## Answers

| Question | Correct Answer | Explanation |
|----------|---------------|-------------|
| 1 | **B** | With `on-by-default: true`, Goldilocks monitors every namespace it can reach. System namespaces (`kube-system`, `goldilocks`, `vpa`) contain Deployments that VPA will happily create objects for. This is mostly harmless but adds noise. More importantly, some system Deployments have unusual resource patterns that produce misleading recommendations. Always pair `on-by-default` with `exclude-namespaces` listing at minimum `kube-system,goldilocks,vpa`. |
| 2 | **C** | Goldilocks v4.15.x does not support per-Deployment exclusion via annotations or labels. The controller operates at the namespace level. The practical workarounds are: (1) move the deployment to a separate namespace that lacks the Goldilocks label, (2) manually delete the VPA it creates (Goldilocks will recreate it on next reconcile), or (3) use `include-namespaces` at the controller level to tightly scope what Goldilocks manages. |
| 3 | **B** | The Goldilocks controller is the authoritative owner of VPAs it creates. On each reconcile cycle (every ~30-60 seconds), it ensures the VPA spec matches what it expects — `targetRef` pointing to the Deployment and `updateMode: "Off"`. Any manual edits to the `spec` are silently overwritten. For durable VPA resource policies, create a separate manually-managed VPA alongside the Goldilocks one, or enforce floors via an admission controller. |
| 4 | **C** | The `dashboard.excludeContainers` setting takes a comma-separated list of container names to hide from the UI. Setting it to `istio-proxy` (or `linkerd-proxy,istio-proxy` for mixed environments) removes sidecar rows from all deployments in all namespaces. This is a dashboard-level filter — the VPA recommendations are still computed and stored; they just aren't displayed. |
