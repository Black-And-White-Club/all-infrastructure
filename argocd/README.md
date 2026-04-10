# Argo CD

This directory is the current GitOps source of truth for `all-infrastructure`.

The root application is [`root-app.yaml`](./root-app.yaml), an Argo CD `Application` that reconciles the platform, observability, app, cluster-resource, and project definitions in this directory.

For the current architecture and ownership model, see [`docs/ARCHITECTURE.md`](../docs/ARCHITECTURE.md).

## Bootstrap

1. Provision OCI resources with Terraform.
2. Bootstrap the cluster and install Argo CD with Ansible.
3. Apply [`root-app.yaml`](./root-app.yaml) if Ansible has not already done so.

```bash
cd ansible
ansible-playbook -i inventory/hosts.ini playbooks/bootstrap-argocd.yml
```

## Layout

- `apps/`: application Argo CD `Application` resources
- `cluster-resources/`: Argo CD applications for namespaces, storage, network policies, dashboards, and secrets
- `image-updaters/`: Argo CD Image Updater custom resources
- `observability/`: shared observability stack applications
- `platform/`: shared platform component applications
- `projects/`: AppProject policy

## Operations

```bash
KUBECONFIG=~/.kube/config-oci kubectl get applications -n argocd -w
KUBECONFIG=~/.kube/config-oci kubectl port-forward svc/argocd-server -n argocd 8081:443
```

## Notes

- Child applications use sync waves to keep CRDs/controllers/resources ordered.
- Argo CD Image Updater writes approved image changes back to Git under this repo.
- Secrets are sourced from the private `all-infrastructure-secrets` repo via the cluster-sealed-secrets application.
