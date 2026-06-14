#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

CLUSTER_NAME="${CLUSTER_NAME:-goldilocks-demo}"

echo ""
echo "================================"
echo " Goldilocks Tutorial — Cleanup"
echo "================================"
echo ""

echo -e "${YELLOW}This will delete the k3d cluster '$CLUSTER_NAME' and all data inside it.${NC}"
read -rp "Continue? [y/N] " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "Cancelled."
  exit 0
fi

if k3d cluster list 2>/dev/null | grep -q "^$CLUSTER_NAME"; then
  echo "Deleting cluster '$CLUSTER_NAME'..."
  k3d cluster delete "$CLUSTER_NAME"
  echo -e "${GREEN}  ✅ Cluster '$CLUSTER_NAME' deleted.${NC}"
else
  echo -e "${YELLOW}  ⚠️  Cluster '$CLUSTER_NAME' not found — nothing to delete.${NC}"
fi

echo ""
echo "Cleanup complete. To start fresh, run:"
echo "  bash scripts/setup-cluster.sh"
echo ""
