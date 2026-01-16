#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHART_DIR="$(dirname "$SCRIPT_DIR")"
NAMESPACE="openshift-lws-operator"

echo "=== Cleaning up LWS operator ==="

# Delete LeaderWorkerSetOperator CR first
echo "Deleting LeaderWorkerSetOperator CR..."
if kubectl get leaderworkersetoperator cluster &>/dev/null; then
  # Try normal delete first
  kubectl delete leaderworkersetoperator cluster --timeout=30s 2>/dev/null || {
    # If stuck, remove finalizers and force delete
    echo "CR stuck, removing finalizers..."
    kubectl patch leaderworkersetoperator cluster --type=json -p='[{"op": "remove", "path": "/metadata/finalizers"}]' 2>/dev/null || true
    kubectl delete leaderworkersetoperator cluster --ignore-not-found
  }
fi

# Destroy helmfile release
cd "$CHART_DIR"
echo "Destroying helmfile release..."
helmfile destroy || true

# Delete operator namespace
echo "Deleting operator namespace..."
kubectl delete namespace $NAMESPACE --ignore-not-found --timeout=60s || {
  # If namespace stuck, force deletion
  echo "Namespace stuck, forcing deletion..."
  kubectl get all -n $NAMESPACE -o name 2>/dev/null | xargs -r kubectl delete -n $NAMESPACE --force --grace-period=0 || true
  kubectl delete namespace $NAMESPACE --ignore-not-found --force --grace-period=0 || true
}

# Delete CRDs
echo "Deleting LWS CRDs..."
kubectl delete crd leaderworkersetoperators.operator.openshift.io --ignore-not-found
kubectl delete crd leaderworkersets.leaderworkerset.x-k8s.io --ignore-not-found 2>/dev/null || true

echo "=== Cleanup complete ==="
