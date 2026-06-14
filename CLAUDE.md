# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

Educational tutorial repository teaching Kubernetes resource right-sizing with **Fairwinds Goldilocks** (v4.15.1). Published on Devoriales. Target audience: Kubernetes administrators who are beginners to resource optimization.

## Tutorial Series

This repo is a 9-lesson tutorial series walking learners through installing Goldilocks, enabling namespaces, reading dashboard recommendations, applying them, and using advanced configuration.
Sample app: `metrics-app` — three services with intentionally wrong resource settings.
See `.taskmaster/docs/prd.txt` for the full lesson plan.
Use Task Master MCP tools to track implementation progress.

## Architecture

- Each lesson lives in its own subdirectory (e.g., `01-intro-resource-problem/`)
- Each subdirectory is a self-contained **Docsify** site: `index.html` (Docsify loader) + `README.md` (content) + `QUIZ.md` (quiz)
- No build step — Docsify renders Markdown client-side from CDN (`//cdn.jsdelivr.net/npm/docsify@4`)
- The `index.html` references `README.md` via `homepage: 'README.md'` in Docsify config
- Docsify theme color: `#f5a623` (golden, matching the Goldilocks brand)

## Critical Technical Details

- **Container registry**: `us-docker.pkg.dev/fairwinds-ops/oss/goldilocks:v4.15.1` — the old `quay.io/fairwinds/goldilocks` path is deprecated as of v4.15.0 and will fail to pull
- **Goldilocks Helm chart**: version `10.4.0`, app version `v4.15.1`
- **k3d cluster name**: `goldilocks-demo`
- **VPA**: Install separately from kubernetes/autoscaler BEFORE installing Goldilocks
- **metrics-server**: Must use `--kubelet-insecure-tls` flag in k3d (no valid certs on loopback)
- **Goldilocks namespace**: `goldilocks`
- **Sample app namespace**: `metrics-app`
- **Namespace label to enable Goldilocks**: `goldilocks.fairwinds.com/enabled=true`
- **VPA naming convention**: Goldilocks creates VPAs named `goldilocks-<deployment-name>`

## Docsify CDN Scripts — SRI Decision

All `index.html` files load Docsify and plugins from `cdn.jsdelivr.net` without Subresource Integrity (SRI) hashes. This is intentional:
- URLs use semver ranges (`@4`, `@2`) — SRI hashes would break on any jsDelivr patch update
- The tutorial is served locally (`npx serve` / `python3 -m http.server`), not as a public website
- Matches the pattern of the Traefik reference tutorial in this repo family

If publishing to a public URL in the future, pin exact CDN versions and compute SRI hashes.

## Serving Locally

```bash
# From any lesson directory:
npx serve 01-intro-resource-problem
# or
python3 -m http.server 3000 --directory 01-intro-resource-problem
# Then open http://localhost:3000
```

## Content Conventions

- **Legend system**: 🎯 Goldilocks-managed resource | ⚠️ Common pitfall | ✅ Verified working | 💡 Best practice
- All YAML examples must be valid Kubernetes manifests with correct `apiVersion`, `kind`, and `metadata`
- Every shell command must be tested and working (no aspirational or untested commands)
- Every lesson README has a navigation line at the top: `> **Duration**: ~X minutes | **Level**: Beginner | [← Previous](../XX/) | [Next →](../XX/)`
- Code examples in lessons must include comments explaining the "Use Case" or "Why"

## Sample App: metrics-app

Three intentionally misconfigured deployments to generate educational Goldilocks recommendations:

| Service | Image | Problem | QoS |
|---------|-------|---------|-----|
| `frontend` | nginx:stable | Over-provisioned (cpu: 500m, memory: 512Mi req=limit) | Guaranteed |
| `api` | kennethreitz/httpbin | Under-provisioned (cpu: 10m, memory: 16Mi req; cpu: 100m, 64Mi limit) | Burstable |
| `worker` | python:3.11-alpine | Mis-sized (cpu: 50m/1000m, memory: 32Mi/128Mi) | Burstable |
| `load-generator` | busybox | Generates traffic so VPA has data | BestEffort-ish |

## Accuracy and Fact-Checking

**Accuracy is the top priority.** Readers are Kubernetes administrators who will run these commands in their clusters.

- Never use the old `quay.io/fairwinds/goldilocks` registry path — always use `us-docker.pkg.dev/fairwinds-ops/oss/goldilocks`
- VPA recommendations are unreliable for the first ~8 days — always caveat early recommendations
- Do not suggest VPA `Auto` mode for production without explaining the pod disruption risk
- Verify all `kubectl` command output examples match what the learner will actually see
- When uncertain: check https://goldilocks.docs.fairwinds.com/ or https://github.com/FairwindsOps/goldilocks

## When Adding or Editing Lessons

1. Each lesson folder: `NN-kebab-case/` with `index.html`, `README.md`, `QUIZ.md`
2. Copy `index.html` from an existing lesson, update: `<title>`, `<meta name="description">`, `window.$docsify.name`
3. README.md structure: Overview → Learning Objectives → Prerequisites → Content → Verification → What's Next
4. QUIZ.md structure: 4-5 practical questions, answers section with explanations
5. The "Back to All Lessons" button in `index.html` navigates to `../` — keep this relative path
