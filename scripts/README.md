# Scripts

Helper scripts for the Goldilocks tutorial. All scripts are written for **bash** and tested on macOS.

## Usage

```bash
# Make scripts executable (first time only)
chmod +x scripts/*.sh

# Or run directly with bash
bash scripts/<script-name>.sh
```

## Scripts

### `verify-prerequisites.sh`

Checks that all required tools are installed and Docker is running.

```bash
bash scripts/verify-prerequisites.sh
```

**Checks:** Docker (running), k3d (≥5.0), kubectl, helm (≥3.10), jq (optional)

---

### `setup-cluster.sh`

Creates the k3d cluster and installs VPA and metrics-server. Run this once at the start of Lesson 02.

```bash
bash scripts/setup-cluster.sh
```

**What it does:**
1. Creates `goldilocks-demo` k3d cluster (1 server + 2 agents)
2. Installs metrics-server via Helm (with `--kubelet-insecure-tls` for k3d)
3. Installs VPA via `fairwinds-stable/vpa` Helm chart into the `vpa` namespace
4. Waits for all components to be ready

**Environment variables:**
- `CLUSTER_NAME` — override cluster name (default: `goldilocks-demo`)
- `VPA_CHART_VERSION` — override VPA Helm chart version (default: `4.12.0`)

---

### `verify-goldilocks.sh`

Verifies Goldilocks is properly installed after Lesson 04.

```bash
bash scripts/verify-goldilocks.sh
```

**Checks:** VPA CRDs, Goldilocks namespace, controller pod Running, dashboard pod Running, image registry (warns if using deprecated quay.io path), dashboard service

---

### `deploy-sample-app.sh`

Deploys the `metrics-app` sample application to the cluster. Run after cluster setup (Lesson 03 or via this script before Lesson 05).

```bash
bash scripts/deploy-sample-app.sh
```

**Deploys:** namespace, frontend (nginx), api (httpbin), worker (python), load-generator (busybox)

> **Note:** The namespace is created WITHOUT the Goldilocks label — that is added manually in Lesson 05 as part of the learning exercise.

---

### `cleanup.sh`

Deletes the k3d cluster and all tutorial resources.

```bash
bash scripts/cleanup.sh
```

This is destructive and irreversible. It deletes the entire `goldilocks-demo` cluster.
