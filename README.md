# all-infrastructure (shared platform skeleton)

This repository is the shared platform/infra repo that will hold everything required to provision and operate the Kubernetes clusters and platform services that multiple projects can consume.

Purpose

- Provision cloud resources and VMs for clusters (Terraform modules)
- Provide bootstrap / configuration playbooks (Ansible)
- Install core platform services (ArgoCD, ingress, cert-manager)
- Host cluster-level resources (namespaces, storage classes, PVs)
- Install and manage the observability stack (Prometheus, Grafana, Loki, Tempo, Alloy)
- Install cluster-level operators (sealed-secrets controller if centralized)
  Postgres instances are managed by per-app Helm charts by default.

Repository layout (skeleton)

- `terraform/` — shared Terraform modules and example environment configs
  - `modules/compute/`
  - `modules/identity-users/`
  - `modules/load-balancer/`
- `ansible/` — playbooks to bootstrap and configure clusters (control plane + nodes)
- `cluster-resources/` — Namespaces, StorageClasses, PV templates, cluster RBAC
- `argocd-applications/` — platform-level ArgoCD `Application`/`ApplicationSet` manifests
- `manifests/` — per-application, raw Kubernetes manifests previously hosted in app-specific infra repos (move app manifests here for consolidated GitOps)
- `observability/` — Helm values and small examples for Prometheus/Grafana/Loki/Tempo/Alloy
- `operators/` — operator install values/CR examples (sealed-secrets)
- `MIGRATION.md` — guidance and commands for moving files from the project repos

Quick notes

- This repo is intended to be the single source of truth for shared platform resources. Project repositories (e.g. `frolf-bot-infrastructure` and `resume-infrastructure`) should keep application charts, per-project ArgoCD ApplicationSets, and app-specific secrets/configs.
- For monitoring, the recommended approach is one shared Prometheus + Grafana stack that scrapes all namespaces; use folders/teams and dashboard tenancy to isolate views.
- Install ArgoCD in this repo (via Helm) and let it reconcile ApplicationSets stored in the project repos.

Getting started (very high-level)

1. Create or select a dev environment configuration in `terraform/` and provision the cloud bits (VCN/Networking/VMs).
2. Run ansible playbooks in `ansible/` to bootstrap the cluster (kubeadm / kubeadm-like flow or other bootstrap tooling).
3. Install ArgoCD (Helm values are in `charts/` or `argocd/`) and register cluster.
4. Apply `argocd-applications/platform-*` to deploy cluster-resources and observability.
5. Point project repos' ApplicationSets at ArgoCD to deploy apps.

If you want help with any of the steps above (creating module implementations, writing a specific helm `values.yaml`, or crafting `git subtree` commands to preserve history) open an issue or ask for the next step.

Moving an app into `all-infrastructure`:

1. Create a `manifests/<app-name>/` folder and copy K8s manifests and any `kustomization.yaml` files.
2. Update corresponding ArgoCD `Application` in `argocd-applications/apps/` to point to the new `manifests/<app-name>` path.
3. Optionally add a `sealed-secrets/<app>-*.yaml` to `cluster-resources/sealed-secrets/` and update any image-updater configs to use `repo-all-infrastructure`.

Make sure to coordinate with app teams for the final step: deleting old infra from the app repo to avoid drift.

Approach B: The Lich King Pattern (recommended)

This repository supports a Lich King pattern to control AppSets and sync behavior. In short:

- `the-lich-king` is an Application that creates only ApplicationSets (found in `argocd-applications/`).
- ApplicationSets are each configured with a category-level sync policy (cluster resources, infra, observability, secrets, apps).
- Apps in `argocd-applications/apps/` are manual by default and must opt-in to automated sync via their `syncPolicy` (safety for workloads).

If you experience corrupted ArgoCD state or a lot of stuck operations, the `ansible/playbooks/nuke-argocd.yml` playbook provides a documented, repeatable way to remove ArgoCD and re-bootstrap it with `ansible/playbooks/bootstrap-argocd.yml`. Use with extreme care — it will erase ArgoCD state and must be followed by a re-install if you intend to continue GitOps with this repo.

If you want to keep the ArgoCD installation but remove all generated Applications and re-run the bootstrap to pick up corrected manifests (safer than nuke):

1. Scale down the ApplicationSet controller (prevents re-creating Applications while you clean up):

```bash
kubectl -n argocd scale deployment argocd-applicationset-controller --replicas=0
kubectl -n argocd scale statefulset argocd-application-controller --replicas=0
```

2. Optionally run the Ansible helper to prune all non-core applications (it will keep `the-lich-king` and `sealed-secrets`):

```bash
ansible-playbook ansible/playbooks/prune-argocd-apps.yml
```

3. Fix repository errors (for example, invalid YAML in `cluster-resources/cronjobs/`), commit and push to Git.

4. Re-enable the Application controllers and sync Lich King to re-create AppSets and Applications:

````bash
kubectl -n argocd scale deployment argocd-applicationset-controller --replicas=1
kubectl -n argocd scale statefulset argocd-application-controller --replicas=1
If you're targeting a remote kubeconfig, either export KUBECONFIG in your shell or pass kubeconfig_path to the Ansible playbook:

```bash
# Option A: Export env var (recommended when running on a control plane host)
export KUBECONFIG=~/.kube/config-oci
kubectl -n argocd scale deployment argocd-applicationset-controller --replicas=1
kubectl -n argocd scale statefulset argocd-application-controller --replicas=1

# Option B: pass kubeconfig_path to Ansible (explicit)
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/prune-argocd-apps.yml -e kubeconfig_path=~/.kube/config-oci
```

Note: playbooks default to running without sudo. If you must run privileged tasks (for example, creating directories that require root on the control-plane host or running sudo commands), add `-e use_sudo=true` and pass `-K` to get the sudo password prompt:

```bash
ansible-playbook -i ansible/inventory/hosts.ini ansible/playbooks/prune-argocd-apps.yml -e kubeconfig_path=~/.kube/config-oci -e use_sudo=true -K
```

Tip: If you prefer to use the ArgoCD CLI (you're already logged in on your workstation), you can use it for manual verification and sync instead of running the playbook checks:

```bash
# list apps
argocd app list

# sync the Lich King to (re)create AppSets
argocd app sync the-lich-king

# terminate in-flight operations
argocd app terminate-op <app-name>
```

argocd app sync the-lich-king

```

After this, apps should re-create from corrected AppSets and manifest files under `all-infrastructure`. If you find that some apps automatically re-apply and you don't want that, set `spec.syncPolicy.automated.enabled=false` on the Application CR or annotate it with `argocd.argoproj.io/skip-reconcile: "true"`.
```
````
