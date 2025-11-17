#!/usr/bin/env bash
set -euo pipefail

KUBECONFIG=${KUBECONFIG:-~/.kube/config-oci}
NAMESPACE=${1:-resume-db}
STSTS=${2:-resume-backend}
PVC_NAME=${3:-data-resume-backend-0}

echo "[info] kubeconfig: $KUBECONFIG"
echo "[info] namespace: $NAMESPACE, statefulset: $STSTS, pvc: $PVC_NAME"

read -p "Make sure you have backups and there is no critical data in the PVC. Continue? (y/N) " confirm
[ "${confirm}" = "y" ] || { echo "Aborting" ; exit 1; }

echo "Scaling down StatefulSet $STSTS in namespace $NAMESPACE"
kubectl --kubeconfig "$KUBECONFIG" -n "$NAMESPACE" scale statefulset "$STSTS" --replicas=0

echo "Removing finalizers and deleting PVC $PVC_NAME..."
kubectl --kubeconfig "$KUBECONFIG" -n "$NAMESPACE" patch pvc "$PVC_NAME" -p '{"metadata":{"finalizers":[]}}' --type=merge || true
kubectl --kubeconfig "$KUBECONFIG" -n "$NAMESPACE" delete pvc "$PVC_NAME" --wait=false || true

echo "Waiting a few seconds for controller to notice PVC deletion..."
sleep 3

echo "Scaling up StatefulSet $STSTS in namespace $NAMESPACE"
kubectl --kubeconfig "$KUBECONFIG" -n "$NAMESPACE" scale statefulset "$STSTS" --replicas=1

echo "Done. New PVC should be created with storage class configured in the chart."
kubectl --kubeconfig "$KUBECONFIG" -n "$NAMESPACE" get pvc
