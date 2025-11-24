# all-infrastructure (shared platform skeleton)

This repository is the shared platform/infra repo that provisions/kicks off the Kubernetes clusters, platform services, and GitOps automation that underpin every project in this organization.

## Purpose

- Provision cloud networking, compute, and storage via `terraform/`.
- Bootstrap/minutely configure clusters, install ArgoCD, and manage certificates/secrets via `ansible/` + Helm.
- Store the shared Kubernetes manifests that every tenant consumes (namespaces, storage classes, CRDs, secrets).
- Host the GitOps control plane under `argocd/`: the root `Application` plus platform, observability, and app definitions.
- Keep per-app Kustomize bases + lightweight overlays in `kustomize/` so Image Updater + ArgoCD can work together.

## Repository layout

- `terraform/` — reusable modules + example environment configs for networking, compute, and database storage.
- `ansible/` — bootstrap playbooks (install ArgoCD, configure storage, apply GitOps manifests).
- `cluster-resources/` — raw YAML for namespaces, storage classes, PVC templates, and other cluster-scoped resources.
- `argocd/` — master GitOps layout; includes `root-app.yaml`, `projects/`, `cluster-resources/`, `platform/`, `observability/`, `apps/`, and helper manifests.
- `charts/` — Helm values/overrides for ArgoCD, image-updaters, monitoring, etc.
- `kustomize/` — per-application Kustomize bases plus `overlays/production` that ArgoCD points to.
- `deprecated/` — relocated/deleted content such as the old `multi-source-apps` directory.
- `docs/`, `MIGRATION*.md` — reference material for migrations, patterns, and workflows.

## Getting started

1. Provision the infrastructure you need (VCN/subnets/VMs) by running the Terraform configurations in `terraform/`.
2. Run `ansible/playbooks/bootstrap-argocd.yml` (set `KUBECONFIG` or pass `-e kubeconfig_path=...`) to install ArgoCD via Helm and apply `argocd/root-app.yaml` plus the consolidated project definitions.
3. The root Application automatically includes `argocd/platform/`, `argocd/observability/`, `argocd/apps/`, `argocd/cluster-resources/`, and `argocd/projects/`. Watch it with `kubectl -n argocd get applications | grep root` or via the ArgoCD UI.
4. Make future changes by editing the relevant YAML under `kustomize/`, `argocd/apps/`, or `argocd/platform/`, then commit/push; ArgoCD will reconcile them through the root app.

## GitOps orchestration

`argocd/root-app.yaml` is the master Application (app-of-apps) that recursively syncs the platform, observability, apps, projects, and cluster-resources directories. Each child Application is scoped to a project (platform, observability, apps) so RBAC stays simple while still reconciling everything under `argocd/`.

If you need to resync everything, re-apply `argocd/root-app.yaml` or use the ArgoCD UI/CLI to refresh the `root` Application. The Ansible bootstrap playbook already applies the latest version after ArgoCD is installed.

## Managing applications

To add a new workload:

1. Create `kustomize/<app>/base/kustomization.yaml` with all of the resources (`Deployment`, `Service`, `ConfigMap`, `SealedSecret`, etc.). Do **not** set `namespace` there; the ArgoCD `Application.destination` sets that.
2. Add `kustomize/<app>/overlays/production/kustomization.yaml` that simply references `../../base`. Keep overlays thin and only add patches when necessary.
3. Create an ArgoCD `Application` manifest under `argocd/apps/<app>.yaml` that targets the production overlay and sets `project: apps`.
4. Commit the new manifests; the root app will pick them up and deploy them automatically.

The repository currently controls Grafana under `argocd/observability/grafana-app.yaml`. Additional observability charts (Tempo, Alloy, Loki, Mimir) can be added later under the same directory.

## Maintenance notes

- The `deprecated/` directory collects old layouts such as `multi-source-apps/` so you can reference the previous setup without cluttering the main tree.
- If you ever need to tear down ArgoCD and start fresh, `ansible/playbooks/nuke-argocd.yml` still removes the installation; re-running the bootstrap playbook re-applies the root Application and projects.
- The `prune-argocd-apps.yml` playbook is legacy and will not fully clean up the new root-app layout, so prefer manual operations (delete the ArgoCD Application under `argocd/apps/` and commit) when removing workloads.

If you need help with a specific platform component or getting a new app onto the GitOps conveyor, open an issue or ping the platform team with the desired repo/name.
