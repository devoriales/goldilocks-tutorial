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

echo ""
echo "Goldilocks Tutorial — Prerequisite Check"
echo "========================================="
echo ""

# Docker
echo "Checking Docker..."
if command -v docker &>/dev/null; then
  if docker info &>/dev/null 2>&1; then
    pass "Docker is running ($(docker --version | head -1))"
  else
    fail "Docker is installed but not running. Start Docker Desktop and try again."
  fi
else
  fail "Docker not found. Install from https://www.docker.com/products/docker-desktop/"
fi

# k3d
echo "Checking k3d..."
if command -v k3d &>/dev/null; then
  K3D_VERSION=$(k3d version | head -1 | grep -oE '[0-9]+\.[0-9]+' | head -1)
  K3D_MAJOR=$(echo "$K3D_VERSION" | cut -d. -f1)
  if [[ "$K3D_MAJOR" -ge 5 ]]; then
    pass "k3d >= 5.0 found ($(k3d version | head -1))"
  else
    warn "k3d found but version $K3D_VERSION is older than 5.0. Upgrade: brew upgrade k3d"
  fi
else
  fail "k3d not found. Install: brew install k3d"
fi

# kubectl
echo "Checking kubectl..."
if command -v kubectl &>/dev/null; then
  KUBECTL_VERSION=$(kubectl version --client -o json 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['clientVersion']['major']+'.'+d['clientVersion']['minor'])" 2>/dev/null || echo "unknown")
  pass "kubectl found (client version: $KUBECTL_VERSION)"
else
  fail "kubectl not found. Install: brew install kubectl"
fi

# helm
echo "Checking Helm..."
if command -v helm &>/dev/null; then
  HELM_VERSION=$(helm version --short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+' | head -1)
  HELM_MAJOR=$(echo "$HELM_VERSION" | tr -d 'v' | cut -d. -f1)
  HELM_MINOR=$(echo "$HELM_VERSION" | tr -d 'v' | cut -d. -f2)
  if [[ "$HELM_MAJOR" -ge 3 && "$HELM_MINOR" -ge 10 ]]; then
    pass "Helm >= 3.10 found ($(helm version --short))"
  else
    warn "Helm $HELM_VERSION found but 3.10+ recommended. Upgrade: brew upgrade helm"
  fi
else
  fail "Helm not found. Install: brew install helm"
fi

# jq (optional but useful for JSON output in lessons)
echo "Checking jq (optional)..."
if command -v jq &>/dev/null; then
  pass "jq found ($(jq --version))"
else
  warn "jq not found. Optional, but useful for Lesson 07. Install: brew install jq"
fi

echo ""
if [[ "$FAILED" -ne 0 ]]; then
  echo -e "${RED}Prerequisites check FAILED. Fix the errors above before continuing.${NC}"
  exit 1
else
  echo -e "${GREEN}All required prerequisites are satisfied. Ready to start!${NC}"
fi
echo ""
