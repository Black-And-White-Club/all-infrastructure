#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBESPRAY_DIR="$SCRIPT_DIR/../external/kubespray"

echo "Deploying Kubernetes cluster using Kubespray..."
cd "$KUBESPRAY_DIR"
ansible-playbook -i "$SCRIPT_DIR/inventory/hosts.ini" playbooks/cluster.yml

echo "Cluster deployment complete!"
echo "To check status: ansible -i $SCRIPT_DIR/inventory/hosts.ini all -m shell -a 'kubectl get nodes'"
