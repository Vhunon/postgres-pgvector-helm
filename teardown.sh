#!/usr/bin/env bash
# teardown.sh â remove the Helm release and optionally delete the k3d cluster
set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-pgvector-dev}"
NAMESPACE="${NAMESPACE:-default}"
CLUSTER_NAME="${CLUSTER_NAME:-pgvector-dev}"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${GREEN}[teardown]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC}  $*"; }

# âââ Uninstall Helm release âââââââââââââââââââââââââââââââââââââââââââââââââââ
if helm status "${RELEASE_NAME}" -n "${NAMESPACE}" &>/dev/null; then
  info "Uninstalling Helm release '${RELEASE_NAME}'â¦"
  helm uninstall "${RELEASE_NAME}" -n "${NAMESPACE}"
else
  warn "Release '${RELEASE_NAME}' not found in namespace '${NAMESPACE}' â skipping."
fi

# âââ Delete PVC (not removed by Helm by default) âââââââââââââââââââââââââââââ
PVC="${RELEASE_NAME}-postgres-pgvector"
if kubectl get pvc "${PVC}" -n "${NAMESPACE}" &>/dev/null; then
  info "Deleting PVC '${PVC}'â¦"
  kubectl delete pvc "${PVC}" -n "${NAMESPACE}"
fi

# âââ Optionally delete k3d cluster âââââââââââââââââââââââââââââââââââââââââââ
if command -v k3d &>/dev/null && k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
  read -rp "Delete k3d cluster '${CLUSTER_NAME}'? [y/N] " yn
  if [[ "${yn,,}" == "y" ]]; then
    info "Deleting k3d cluster '${CLUSTER_NAME}'â¦"
    k3d cluster delete "${CLUSTER_NAME}"
  else
    info "Cluster left intact."
  fi
fi

info "Teardown complete."
