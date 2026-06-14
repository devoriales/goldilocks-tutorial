# Quiz — Lesson 01: The Resource Requests Problem

## Question 1

**A pod's memory usage exceeds its memory limit. What happens?**

- A. The pod slows down until memory usage drops below the limit
- B. The pod is OOMKilled and restarted by Kubernetes
- C. The pod is migrated to a node with more memory
- D. The pod continues running but the limit is automatically raised

## Question 2

**Your API pod has `requests.cpu: 10m` and `limits.cpu: 200m`. The pod consistently uses 150m CPU under load. What is the likely symptom?**

- A. The pod is OOMKilled repeatedly
- B. The pod is evicted from the node
- C. The pod responds slowly due to CPU throttling
- D. The pod fails to schedule because no node has 150m available

## Question 3

**A deployment has `requests.cpu: 500m, requests.memory: 512Mi` and `limits.cpu: 500m, limits.memory: 512Mi`. What QoS class is assigned?**

- A. BestEffort
- B. Burstable
- C. Guaranteed
- D. Critical

## Question 4

**Your cluster has 3 nodes and is running low on memory. Which pod type is evicted FIRST?**

- A. A pod with Guaranteed QoS (requests == limits)
- B. A pod with Burstable QoS (requests < limits)
- C. A pod with BestEffort QoS (no requests or limits)
- D. All pods are evicted simultaneously

---

## Answers

| Question | Correct Answer | Explanation |
|----------|---------------|-------------|
| 1 | **B** | Memory limits are enforced by the Linux OOM killer. When a container exceeds its memory limit, the kernel sends SIGKILL (exit code 137). Kubernetes sees the container as failed and restarts it. Unlike CPU, memory cannot be "throttled" — it either fits or the process dies. |
| 2 | **C** | CPU limits are enforced by the Linux CFS scheduler via CPU throttling. The container is not killed; instead, the scheduler restricts how much CPU time it gets. The pod runs, but slowly. This is a "silent" failure — no alerts fire, but users experience latency. |
| 3 | **C** | When requests == limits for all containers in a pod (and both are set), Kubernetes assigns the Guaranteed QoS class. This pod is last to be evicted under memory pressure — but in this case, the values are probably wrong (500m CPU and 512Mi memory for nginx idle). |
| 4 | **C** | Kubernetes evicts in order: BestEffort first (no requests/limits set, no protection), then Burstable (if usage exceeds requests), then Guaranteed (last resort). Setting resource requests is the minimum you need to avoid being the first pod evicted. |
