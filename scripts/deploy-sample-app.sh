#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()    { echo -e "${BLUE}  →${NC} $1"; }
success() { echo -e "${GREEN}  ✅${NC} $1"; }
warn()    { echo -e "${YELLOW}  ⚠️${NC}  $1"; }
die()     { echo -e "${RED}  ❌ ERROR${NC}: $1"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
APP_DIR="$REPO_ROOT/sample-app"
APP_NS="${APP_NAMESPACE:-metrics-app}"

echo ""
echo "================================"
echo " Deploying metrics-app"
echo "================================"
echo ""

[[ -d "$APP_DIR" ]] || die "sample-app/ directory not found at $APP_DIR"

# Namespace (without Goldilocks label — added in Lesson 05)
info "Creating namespace '$APP_NS'..."
kubectl apply -f "$APP_DIR/namespace.yaml"

# Deploy each service in order
for component in frontend api worker load-generator; do
  DIR="$APP_DIR/$component"
  if [[ -d "$DIR" ]]; then
    info "Deploying $component..."
    kubectl apply -f "$DIR/"
  else
    warn "No directory found for $component at $DIR, skipping."
  fi
done

# Wait for workloads
info "Waiting for pods to be Ready (up to 120s)..."
kubectl wait --for=condition=Ready pods \
  --all \
  -n "$APP_NS" \
  --timeout=120s \
  2>/dev/null || warn "Some pods not yet Ready — this can happen if images are still pulling. Check: kubectl get pods -n $APP_NS"

echo ""
success "metrics-app deployed"
echo ""
echo "Pod status:"
kubectl get pods -n "$APP_NS"
echo ""
echo "Next: Enable Goldilocks for this namespace (Lesson 05):"
echo "  kubectl label ns $APP_NS goldilocks.fairwinds.com/enabled=true"
echo ""
