#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { echo -e "${BLUE}  →${NC} $1"; }
success() { echo -e "${GREEN}  ✅${NC} $1"; }
warn()    { echo -e "${YELLOW}  ⚠️${NC}  $1"; }
die()     { echo -e "${RED}  ❌ ERROR${NC}: $1"; exit 1; }

CLUSTER_NAME="${CLUSTER_NAME:-goldilocks-demo}"
VPA_CHART_VERSION="${VPA_CHART_VERSION:-4.12.0}"

echo ""
echo "=========================================="
echo " Goldilocks Tutorial — Cluster Setup"
echo "=========================================="
echo ""

# --- Prerequisites check ---
info "Checking prerequisites..."
for tool in docker k3d kubectl helm; do
  command -v "$tool" &>/dev/null || die "$tool not found. Run scripts/verify-prerequisites.sh first."
done
docker info &>/dev/null 2>&1 || die "Docker is not running. Start Docker Desktop first."
success "Prerequisites OK"

# --- Existing cluster check ---
if k3d cluster list 2>/dev/null | grep -q "^$CLUSTER_NAME"; then
  warn "Cluster '$CLUSTER_NAME' already exists."
  read -rp "  Delete and recreate? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    info "Deleting existing cluster..."
    k3d cluster delete "$CLUSTER_NAME"
  else
    echo "Skipping cluster creation. Using existing cluster."
    kubectl config use-context "k3d-$CLUSTER_NAME"
  fi
fi

# --- Create k3d cluster ---
if ! k3d cluster list 2>/dev/null | grep -q "^$CLUSTER_NAME"; then
  info "Creating k3d cluster '$CLUSTER_NAME' (1 server + 2 agents)..."
  # --disable=metrics-server: skip k3s built-in metrics-server (uses rancher mirror image)
  # We install metrics-server via Helm for a known-good image
  k3d cluster create "$CLUSTER_NAME" \
    --agents 2 \
    --timeout 120s \
    --k3s-arg '--disable=metrics-server@server:0'
  success "Cluster '$CLUSTER_NAME' created"
fi

# --- Wait for nodes ---
info "Waiting for all nodes to be Ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s
NODE_COUNT=$(kubectl get nodes --no-headers | wc -l | tr -d ' ')
success "All $NODE_COUNT nodes are Ready"

# --- Helm repos ---
info "Adding Helm repositories..."
helm repo add fairwinds-stable https://charts.fairwinds.com/stable 2>/dev/null || true
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ 2>/dev/null || true
helm repo update
success "Helm repositories updated"

# --- metrics-server ---
info "Installing metrics-server..."
if helm list -n kube-system | grep -q "^metrics-server"; then
  warn "metrics-server already installed, skipping."
else
  # Single-quote args[0] to prevent zsh from treating [0] as array subscript
  helm install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --set 'args[0]=--kubelet-insecure-tls' \
    --wait \
    --timeout 120s
  success "metrics-server installed"
fi

# --- VPA ---
info "Installing Vertical Pod Autoscaler (VPA) via Helm (chart $VPA_CHART_VERSION)..."
if helm list -n vpa | grep -q "^vpa"; then
  warn "VPA already installed, skipping."
else
  kubectl create namespace vpa 2>/dev/null || true
  helm install vpa fairwinds-stable/vpa \
    --namespace vpa \
    --version "$VPA_CHART_VERSION" \
    --wait \
    --timeout 180s
  success "VPA installed in namespace 'vpa'"
fi

# --- Verify VPA CRDs ---
info "Verifying VPA CRDs..."
kubectl get crd verticalpodautoscalers.autoscaling.k8s.io &>/dev/null \
  || die "VPA CRD 'verticalpodautoscalers.autoscaling.k8s.io' not found. VPA install may have failed."
success "VPA CRDs present"

# --- Verify metrics-server ---
info "Waiting for metrics-server to become available (up to 60s)..."
ATTEMPTS=0
until kubectl top nodes &>/dev/null 2>&1 || [[ $ATTEMPTS -ge 12 ]]; do
  ATTEMPTS=$((ATTEMPTS + 1))
  sleep 5
done
if kubectl top nodes &>/dev/null 2>&1; then
  success "metrics-server is responding (kubectl top nodes works)"
else
  warn "metrics-server not yet responding — this is normal immediately after install. Wait a minute and run 'kubectl top nodes' to verify."
fi

echo ""
echo "=========================================="
echo -e "${GREEN} Setup Complete!${NC}"
echo "=========================================="
echo ""
echo "Cluster:      k3d-$CLUSTER_NAME"
echo "VPA:          namespace 'vpa'"
echo "metrics-server: namespace 'kube-system'"
echo ""
echo "Next steps:"
echo "  1. Install Goldilocks (Lesson 04): helm install goldilocks fairwinds-stable/goldilocks ..."
echo "  2. Or deploy the sample app: bash scripts/deploy-sample-app.sh"
echo ""
