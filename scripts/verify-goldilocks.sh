#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}  ✅ PASS${NC}: $1"; }
fail() { echo -e "${RED}  ❌ FAIL${NC}: $1"; FAILED=1; }
warn() { echo -e "${YELLOW}  ⚠️  WARN${NC}: $1"; }

FAILED=0
GOLDILOCKS_NS="${GOLDILOCKS_NAMESPACE:-goldilocks}"

echo ""
echo "Goldilocks Installation Check"
echo "=============================="
echo ""

# VPA CRDs
echo "Checking VPA CRDs..."
if kubectl get crd verticalpodautoscalers.autoscaling.k8s.io &>/dev/null; then
  pass "VPA CRD 'verticalpodautoscalers.autoscaling.k8s.io' exists"
else
  fail "VPA CRD not found. Install VPA before Goldilocks."
fi

# Goldilocks namespace
echo "Checking Goldilocks namespace..."
if kubectl get ns "$GOLDILOCKS_NS" &>/dev/null; then
  pass "Namespace '$GOLDILOCKS_NS' exists"
else
  fail "Namespace '$GOLDILOCKS_NS' not found. Run: kubectl create namespace $GOLDILOCKS_NS"
fi

# Controller pod
echo "Checking Goldilocks controller pod..."
CONTROLLER_STATUS=$(kubectl get pods -n "$GOLDILOCKS_NS" \
  -l "app.kubernetes.io/component=controller" \
  -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [[ "$CONTROLLER_STATUS" == "Running" ]]; then
  pass "goldilocks-controller is Running"
else
  fail "goldilocks-controller not Running (status: $CONTROLLER_STATUS). Check: kubectl get pods -n $GOLDILOCKS_NS"
fi

# Dashboard pod
echo "Checking Goldilocks dashboard pod..."
DASHBOARD_STATUS=$(kubectl get pods -n "$GOLDILOCKS_NS" \
  -l "app.kubernetes.io/component=dashboard" \
  -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
if [[ "$DASHBOARD_STATUS" == "Running" ]]; then
  pass "goldilocks-dashboard is Running"
else
  fail "goldilocks-dashboard not Running (status: $DASHBOARD_STATUS). Check: kubectl get pods -n $GOLDILOCKS_NS"
fi

# Container image registry (verify using new registry, not quay.io)
echo "Checking container image registry..."
IMAGE=$(kubectl get pods -n "$GOLDILOCKS_NS" \
  -l "app.kubernetes.io/name=goldilocks" \
  -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || echo "")
if [[ "$IMAGE" == us-docker.pkg.dev/* ]]; then
  pass "Using new registry: $IMAGE"
elif [[ "$IMAGE" == quay.io/* ]]; then
  fail "Using deprecated quay.io registry: $IMAGE. Reinstall with --set image.repository=us-docker.pkg.dev/fairwinds-ops/oss/goldilocks"
elif [[ -z "$IMAGE" ]]; then
  warn "Could not determine image (no pods found). Run Lesson 04 first."
fi

# Dashboard service
echo "Checking dashboard service..."
if kubectl get svc goldilocks-dashboard -n "$GOLDILOCKS_NS" &>/dev/null; then
  SVC_PORT=$(kubectl get svc goldilocks-dashboard -n "$GOLDILOCKS_NS" -o jsonpath='{.spec.ports[0].port}')
  pass "goldilocks-dashboard service exists (port $SVC_PORT)"
else
  fail "goldilocks-dashboard service not found"
fi

echo ""
if [[ "$FAILED" -ne 0 ]]; then
  echo -e "${RED}Goldilocks check FAILED. See errors above.${NC}"
  echo ""
  echo "Troubleshooting:"
  echo "  Controller logs: kubectl logs -n $GOLDILOCKS_NS -l app.kubernetes.io/component=controller"
  echo "  All pod events:  kubectl describe pods -n $GOLDILOCKS_NS"
  exit 1
else
  echo -e "${GREEN}Goldilocks is healthy!${NC}"
  echo ""
  echo "Access the dashboard:"
  echo "  kubectl -n $GOLDILOCKS_NS port-forward svc/goldilocks-dashboard 8080:80"
  echo "  Then open: http://localhost:8080"
fi
echo ""
