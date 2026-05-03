#!/usr/bin/env bash
# setup.sh â one-shot script to spin up PostgreSQL + pgvector on k3d or Docker Desktop K8s
set -euo pipefail

RELEASE_NAME="${RELEASE_NAME:-pgvector-dev}"
NAMESPACE="${NAMESPACE:-default}"
CLUSTER_NAME="${CLUSTER_NAME:-pgvector-dev}"
CHART_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/chart" && pwd)"

# âââ Colour helpers ââââââââââââââââââââââââââââââââââââââââââââââââââââââââââ
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[setup]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC}  $*"; }
error() { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }

# âââ Dependency checks âââââââââââââââââââââââââââââââââââââââââââââââââââââââ
check_cmd() {
  command -v "$1" &>/dev/null || error "'$1' not found. Please install it first."
}

check_cmd kubectl
check_cmd helm

# âââ Detect / create cluster âââââââââââââââââââââââââââââââââââââââââââââââââ
if command -v k3d &>/dev/null; then
  info "k3d detected."
  if ! k3d cluster list | grep -q "^${CLUSTER_NAME}"; then
    info "Creating k3d cluster '${CLUSTER_NAME}'â¦"
    k3d cluster create "${CLUSTER_NAME}" \
      --port "5432:30432@loadbalancer" \
      --wait
    info "Cluster created. kubectl context switched automatically."
  else
    info "Cluster '${CLUSTER_NAME}' already exists â using it."
    k3d kubeconfig merge "${CLUSTER_NAME}" --kubeconfig-switch-context
  fi
elif kubectl config current-context 2>/dev/null | grep -qi "docker-desktop"; then
  info "Docker Desktop Kubernetes context detected â proceeding."
else
  warn "k3d not found and current context does not look like Docker Desktop."
  warn "Current context: $(kubectl config current-context 2>/dev/null || echo '<none>')"
  read -rp "Continue anyway? [y/N] " yn
  [[ "${yn,,}" == "y" ]] || exit 1
fi

# âââ Helm install / upgrade ââââââââââââââââââââââââââââââââââââââââââââââââââ
info "Running helm upgrade --install ${RELEASE_NAME} â¦"
helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --wait \
  --timeout 120s

# âââ Port-forward tip (Docker Desktop / non-k3d) âââââââââââââââââââââââââââââ
if ! command -v k3d &>/dev/null; then
  SVC="${RELEASE_NAME}-postgres-pgvector"
  echo ""
  info "To connect, run in a separate terminal:"
  echo "  kubectl port-forward svc/${SVC} 5432:5432 -n ${NAMESPACE}"
fi

# âââ Connection details ââââââââââââââââââââââââââââââââââââââââââââââââââââââ
DB=$(helm get values "${RELEASE_NAME}" -n "${NAMESPACE}" -o json 2>/dev/null | \
  python3 -c "import sys,json; v=json.load(sys.stdin)['postgres']; print(v['database'],v['user'],v['password'])" 2>/dev/null || \
  echo "appdb appuser devpassword")
read -r PGDB PGUSER PGPASSWORD <<< "$DB"

echo ""
info "Done! PostgreSQL + pgvector is ready."
echo ""
echo "  Connection string:  postgresql://${PGUSER}:${PGPASSWORD}@localhost:5432/${PGDB}"
echo "  psql shortcut:      PGPASSWORD=${PGPASSWORD} psql -h localhost -U ${PGUSER} -d ${PGDB}"
echo ""
echo "  Verify pgvector:"
echo "    SELECT extname, extversion FROM pg_extension WHERE extname = 'vector';"
