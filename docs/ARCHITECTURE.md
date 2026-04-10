# Architecture

This is the canonical current-state architecture document for `all-infrastructure`.

## Platform shape

- OCI-based Kubernetes cluster bootstrapped by Ansible/Kubespray.
- Argo CD manages platform, observability, apps, and shared cluster resources from [`argocd/`](../argocd).
- Terraform manages OCI networking, compute, IAM, load balancer, object storage, registry, and block storage from [`terraform/`](../terraform).

## GitOps flow

1. Terraform provisions OCI resources.
2. Ansible bootstraps the cluster and installs Argo CD.
3. [`argocd/root-app.yaml`](../argocd/root-app.yaml) reconciles:
   - `argocd/platform/`
   - `argocd/observability/`
   - `argocd/apps/`
   - `argocd/cluster-resources/`
   - `argocd/projects/`

## Workloads

### Shared platform

- Argo CD
- Argo CD Image Updater
- Sealed Secrets
- cert-manager
- ingress-nginx
- argo-rollouts
- OCI CSI driver

### Shared observability

- Grafana
- Loki
- Mimir
- Tempo
- Alloy
- kube-state-metrics
- node-exporter

### Application namespaces

- `frolf-bot`: frolf backend, discord bot, PWA, NATS, Postgres backup job
- `resume-app`: resume frontend and backend
- `resume-db`: resume Postgres
- `observability`: shared observability stack

## Storage

Preferred state is OCI block storage for persistent volumes and OCI object storage for long-term observability data.

Current intentional local-storage exceptions still managed in this repo:

- [`cluster-resources/pv-grafana.yaml`](../cluster-resources/pv-grafana.yaml)
- [`cluster-resources/pv-loki-local.yaml`](../cluster-resources/pv-loki-local.yaml)
- [`cluster-resources/pv-resume-postgres-local.yaml`](../cluster-resources/pv-resume-postgres-local.yaml)
- [`cluster-resources/pv-tempo-ingester-wal.yaml`](../cluster-resources/pv-tempo-ingester-wal.yaml)
- [`cluster-resources/pvc-resume-postgres.yaml`](../cluster-resources/pvc-resume-postgres.yaml)

Retired comment-only PVC stubs live under [`cluster-resources/retired/`](../cluster-resources/retired).

## Automation

- Helm/provider updates are proposed by Renovate from [`renovate.json`](../renovate.json).
- Application image updates are written back to Git by Argo CD Image Updater from [`argocd/image-updaters/`](../argocd/image-updaters).
- CI validates Terraform, Helm, and Kustomize from [`.github/workflows/ci-validate.yml`](../.github/workflows/ci-validate.yml).
