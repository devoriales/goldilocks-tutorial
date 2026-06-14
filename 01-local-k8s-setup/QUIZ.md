# Quiz — Lesson 02: Local Kubernetes Setup with k3d

## Question 1

**Why do we pass `--k3s-arg '--disable=metrics-server@server:0'` when creating the k3d cluster?**

- A. To make the cluster faster by reducing the number of running components
- B. To avoid a conflict with the VPA admission controller
- C. To prevent k3s from installing its bundled metrics-server so we can install the official version via Helm
- D. metrics-server is not needed for Goldilocks

## Question 2

**Why does the metrics-server Helm installation require `--set 'args[0]=--kubelet-insecure-tls'`?**

- A. To allow metrics-server to scrape metrics from all namespaces
- B. k3d uses self-signed kubelet certificates that metrics-server cannot verify by default
- C. To enable Prometheus metrics export from metrics-server
- D. This flag is required in all Kubernetes environments

## Question 3

**VPA installs three components: recommender, updater, and admission-controller. Which one generates the resource recommendations that Goldilocks displays?**

- A. The updater — it applies recommendations to running pods
- B. The admission-controller — it intercepts pod creation requests
- C. The recommender — it reads metrics history and calculates optimal resource values
- D. All three generate recommendations independently

## Question 4

**After running `kubectl top nodes`, you see `error: Metrics API not available`. What should you do?**

- A. Reinstall metrics-server — the installation failed
- B. Wait 30 seconds and try again — metrics-server needs time to register its API service
- C. Check if VPA is running — the error comes from VPA, not metrics-server
- D. Add `--set 'args[0]=--kubelet-insecure-tls'` and reinstall

---

## Answers

| Question | Correct Answer | Explanation |
|----------|---------------|-------------|
| 1 | **C** | k3s ships with a bundled metrics-server using the `rancher/mirrored-metrics-server` image. Installing a second metrics-server via Helm on top of it causes a ServiceAccount conflict (`already exists and cannot be imported`). Disabling the bundled one first avoids the conflict. |
| 2 | **B** | k3d nodes use self-signed TLS certificates for their kubelet APIs. metrics-server verifies these certificates by default and fails with a TLS error. The `--kubelet-insecure-tls` flag skips this verification — appropriate for local development, not production. |
| 3 | **C** | The VPA recommender reads historical CPU and memory usage from the Kubernetes Metrics API (via metrics-server), builds a statistical model, and outputs `lowerBound`, `target`, and `upperBound` recommendations. Goldilocks reads these VPA recommendation objects and presents them in its dashboard. |
| 4 | **B** | metrics-server registers itself as an API extension (`v1beta1.metrics.k8s.io`). This registration takes 15-30 seconds after the pod starts. If `kubectl top nodes` fails immediately after install, waiting a short time and retrying is the correct response before escalating to troubleshooting. |
