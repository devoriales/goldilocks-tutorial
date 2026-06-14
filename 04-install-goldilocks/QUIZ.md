# Quiz — Lesson 04: Installing Goldilocks

## Question 1

**What are the two components that Goldilocks installs?**

- A. A scraper and an alertmanager
- B. A controller and a dashboard
- C. A recommender and an updater
- D. An admission controller and a scheduler

## Question 2

**What happens immediately after you install Goldilocks but before labeling any namespace?**

- A. Goldilocks automatically labels all namespaces in the cluster
- B. The dashboard shows an error: "VPA not found"
- C. Nothing — the controller waits for namespaces labeled `goldilocks.fairwinds.com/enabled=true`
- D. Goldilocks creates VPA objects for every namespace in the cluster

## Question 3

**Your Goldilocks pod shows `ImagePullBackOff`. The describe output shows it is trying to pull `quay.io/fairwinds/goldilocks:v4.15.1`. What is the fix?**

- A. The image doesn't exist — downgrade to v4.14.0
- B. Add `imagePullPolicy: Never` to avoid pulling from registries
- C. The `quay.io` registry was deprecated in v4.15.0. Override `image.repository` in values.yaml to `us-docker.pkg.dev/fairwinds-ops/oss/goldilocks`
- D. Create an ImagePullSecret for the quay.io registry

## Question 4

**Why does the values.yaml set `vpa.enabled: false` and `metrics-server.enabled: false`?**

- A. Goldilocks doesn't actually need VPA or metrics-server to work
- B. These flags disable bundled sub-charts because we already installed VPA and metrics-server separately in Lesson 02 — installing them twice would cause conflicts
- C. VPA and metrics-server must be installed after Goldilocks, not before
- D. These are deprecated flags that have no effect

---

## Answers

| Question | Correct Answer | Explanation |
|----------|---------------|-------------|
| 1 | **B** | Goldilocks installs two Deployments: the **controller**, which watches for labeled namespaces and manages VPA objects, and the **dashboard**, a web UI that reads VPA recommendations and presents them visually. The VPA recommender and updater are separate VPA components installed in a different step. |
| 2 | **C** | The Goldilocks controller uses a namespace label (`goldilocks.fairwinds.com/enabled=true`) as a trigger. Until you add this label to at least one namespace, the controller takes no action and the dashboard shows "No namespaces found." This is by design — Goldilocks is opt-in per namespace. |
| 3 | **C** | Goldilocks v4.15.0 moved its container image from `quay.io/fairwinds/goldilocks` to `us-docker.pkg.dev/fairwinds-ops/oss/goldilocks`. The old registry is deprecated and pulls will fail. The fix is to set `image.repository: us-docker.pkg.dev/fairwinds-ops/oss/goldilocks` in your Helm values. |
| 4 | **B** | The Goldilocks Helm chart includes optional sub-charts for VPA and metrics-server as a convenience. Setting `enabled: false` disables them. Since we installed standalone VPA (in the `vpa` namespace) and metrics-server (in `kube-system`) in Lesson 02, installing them again via Goldilocks would create ServiceAccount conflicts and duplicate components. Always install VPA and metrics-server independently for better control. |
