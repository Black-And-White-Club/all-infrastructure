#!/bin/bash
# Bootstrap The Lich King on the OCI cluster
# This applies The Lich King ApplicationSet which then manages all platform and application resources

set -e

KUBECONFIG="${KUBECONFIG:-$HOME/.kube/config-oci}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔱 Summoning The Lich King..."
echo "Using kubeconfig: $KUBECONFIG"

# Check if ArgoCD is running
echo "Checking ArgoCD status..."
if ! kubectl get namespace argocd &>/dev/null; then
    echo "❌ ArgoCD namespace not found. Run ansible/playbooks/bootstrap-argocd.yml first"
    exit 1
fi

if ! kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server --field-selector=status.phase=Running &>/dev/null; then
    echo "⚠️  ArgoCD pods not ready. Waiting..."
    kubectl wait --for=condition=Ready pods -n argocd -l app.kubernetes.io/name=argocd-server --timeout=300s
fi

echo "✅ ArgoCD is running"

# Ansible should install ArgoCD + Sealed Secrets and prepare the cluster (one-time).
echo "Note: ArgoCD and Sealed Secrets should be installed via Ansible before running this script."
echo "Skipping application of bootstrap manifests (moved to ansible/infrastructure)."

# Apply The Lich King Application after bootstrap finishes
echo "Applying The Lich King Application..."
kubectl apply -f "$REPO_ROOT/argocd-applications/the-lich-king/the-lich-king.yaml"

echo ""
echo "🎉 The Lich King has been summoned!"
echo ""
echo "Watch the deployment:"
echo "  kubectl get applications -n argocd -w"
echo ""
echo "Access ArgoCD UI:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8081:443"
echo "  https://localhost:8081"
echo ""
echo "Get admin password:"
echo "  kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d"
echo ""
