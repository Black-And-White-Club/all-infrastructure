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
