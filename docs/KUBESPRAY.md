# Kubespray Bootstrap (Cluster Already Running)

The Kubernetes cluster was bootstrapped using [Kubespray](https://github.com/kubernetes-sigs/kubespray).

## Original Setup

The cluster was deployed using Kubespray commit/tag: `<INSERT_COMMIT_OR_TAG_HERE>`

Inventory and configuration used:

- Inventory: `ansible/inventory/hosts.ini`
- Custom vars: `ansible/inventory/group_vars/all/`

## Re-deploying the Cluster (if needed)

If you need to rebuild the cluster from scratch:

1. **Install Kubespray dependencies**:

   ```bash
   # Clone Kubespray (or use ansible-galaxy)
   cd /tmp
   git clone https://github.com/kubernetes-sigs/kubespray.git
   cd kubespray
   git checkout <TAG_OR_COMMIT>  # Use same version as original

   # Install Python requirements
   pip install -r requirements.txt
   ```

2. **Use this repo's inventory**:

   ```bash
   # Copy inventory from this repo
   cp -r /path/to/all-infrastructure/ansible/inventory ./inventory/oci
   ```

3. **Run cluster deployment**:
   ```bash
   ansible-playbook -i inventory/oci/hosts.ini --become cluster.yml
   ```

## Current Cluster Info

- **Control Plane**: 129.153.14.244 (10.0.1.2)
- **Worker-1**: 129.80.81.77 (10.0.1.136)
- **Network Plugin**: Cilium (configured in group_vars)
- **Container Runtime**: containerd

## Post-Deployment Bootstrap

After the cluster is running, use Ansible to bootstrap ArgoCD and let GitOps take over:

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/bootstrap-argocd.yml
```

This installs:

- ArgoCD
- Sealed Secrets (via ArgoCD)
- Root ApplicationSet pointing to this repo

Everything else is managed by ArgoCD from that point forward.
