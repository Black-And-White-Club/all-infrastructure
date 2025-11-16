# Migration Plan: Consolidating to all-infrastructure

## Overview

This guide shows you how to migrate from separate infrastructure repos to a unified **all-infrastructure** platform repo with **The Lich King** as the master orchestrator.

## Architecture After Migration

```
The Lich King (all-infrastructure)
├── Wave 0: Platform Cluster Resources
│   ├── Sealed Secrets
│   ├── cert-manager
│   ├── Ingress NGINX
│   ├── Storage Classes
│   └── Namespaces
├── Wave 1: Platform Observability
│   ├── Grafana (shared)
│   ├── Loki (shared)
│   ├── Tempo (shared)
│   ├── Mimir (shared)
│   └── Alloy (shared)
├── Wave 2: Platform Shared Services
│   └── NATS (Postgres instances are deployed per-app via Helm)
└── Wave 10+: Applications
    ├── Resume (points to resume-infrastructure/resume-app-manifests)
    └── Frolf Bot (points to frolf-bot-infrastructure/frolf-bot-app-manifests + multi-tenant)
```

## Phase 1: Move Infrastructure to all-infrastructure

### From frolf-bot-infrastructure → all-infrastructure

**Move these directories:**

```bash
# Observability charts
frolf-bot-infrastructure/charts/grafana/        → all-infrastructure/charts/grafana/
frolf-bot-infrastructure/charts/loki/           → all-infrastructure/charts/loki/
frolf-bot-infrastructure/charts/tempo/          → all-infrastructure/charts/tempo/
frolf-bot-infrastructure/charts/mimir/          → all-infrastructure/charts/mimir/
frolf-bot-infrastructure/charts/alloy/          → all-infrastructure/charts/alloy/

# Shared services
frolf-bot-infrastructure/charts/nats/           → all-infrastructure/charts/nats/
frolf-bot-infrastructure/charts/postgres-frolf/ → all-infrastructure/charts/postgres/ (per-app Helm chart values)

# Sealed Secrets
frolf-bot-infrastructure/charts/sealed-secrets/ → all-infrastructure/charts/sealed-secrets/
frolf-bot-infrastructure/sealed-secrets/        → all-infrastructure/sealed-secrets/

# Cluster resources (merge with existing)
frolf-bot-infrastructure/cluster-resources/namespaces.yaml → all-infrastructure/cluster-resources/
frolf-bot-infrastructure/cluster-resources/storage-class-*.yaml → all-infrastructure/cluster-resources/
frolf-bot-infrastructure/cluster-resources/pv-*.yaml → all-infrastructure/cluster-resources/
```

**DELETE from frolf-bot-infrastructure:**

- `argocd-applications/` (except keep `the-lich-king/` for multi-tenant guilds)
- `charts/` (all except application-specific charts if any)
- `multi-source-apps/`
- `observability/`
- `sealed-secrets/` (moved to all-infrastructure)

**KEEP in frolf-bot-infrastructure:**

- `frolf-bot-app-manifests/` (application deployments)
- `multi-tenant/` (guild configs)
- `the-lich-king/` (guild ApplicationSet - rename to avoid confusion)
- `Makefile`, `Tiltfile`, local dev tools

### From resume-infrastructure → all-infrastructure

**Move these:**

```bash
# cert-manager
resume-infrastructure/charts/cert-manager/      → all-infrastructure/charts/cert-manager/
resume-infrastructure/cluster-resources/cluster-cert-issuer.yaml → all-infrastructure/cluster-resources/cert-manager/

# Postgres (if not using operator, keep separate instance)
resume-infrastructure/charts/postgres/          → all-infrastructure/cluster-resources/resume/postgres/

# Prometheus (if you want shared metrics, otherwise remove in favor of Mimir)
resume-infrastructure/charts/prometheus/        → all-infrastructure/charts/prometheus/ (or remove)

# PVs/PVCs
resume-infrastructure/cluster-resources/pv-*.yaml → all-infrastructure/cluster-resources/resume/
```

**DELETE from resume-infrastructure:**

- `argocd-applications/`
- `the-overmind/`
- `multi-source-apps/`
- `charts/argo-cd/` (ArgoCD managed by all-infrastructure)

**KEEP in resume-infrastructure:**

- `resume-app-manifests/` (application deployments only)
- `terraform/` (if resume needs its own cloud resources)

## Phase 2: Update all-infrastructure Structure

Create this structure:

```
all-infrastructure/
├── argocd-applications/
│   ├── the-lich-king.yaml                      # ✅ Created
│   ├── platform/
│   │   ├── platform-cluster-resources.yaml     # ✅ Created
│   │   ├── platform-observability.yaml         # ✅ Created
│   │   └── platform-shared-services.yaml       # ✅ Created
│   └── applications/
│       ├── app-resume.yaml                     # ✅ Created
│       └── app-frolf-bot.yaml                  # ✅ Created
├── charts/                                      # Helm values for all platform services
│   ├── argo-cd/
│   ├── sealed-secrets/
│   ├── cert-manager/
│   ├── grafana/
│   ├── loki/
│   ├── tempo/
│   ├── mimir/
│   ├── alloy/
│   ├── nats/
│   └── postgres/ (per-app helm values)
├── cluster-resources/                           # Raw Kubernetes manifests
│   ├── namespaces.yaml
│   ├── storage-class-oci.yaml
│   ├── cert-manager/
│   │   └── cluster-cert-issuer.yaml
│   ├── resume/
│   │   ├── NOTE: Prometheus/Grafana and Postgres should use dynamic PVCs (oci-block-storage). Do not check hostPath PV YAML into repo.
│   └── frolf-bot/
│       ├── NOTE: The frolf-bot cluster-resources folder historically included hostPath PVs for NATS/Postgres/Grafana. These have been removed in favor of dynamically-provisioned PVCs using StorageClass 'oci-block-storage'.
├── sealed-secrets/                              # All sealed secrets
│   ├── ocir-pull-secret-sealed.yaml
│   ├── argocd-token-sealed.yaml
│   └── backend-secrets-sealed.yaml
├── terraform/                                   # Platform infrastructure
├── ansible/                                     # Cluster bootstrap
└── README.md
```

## Phase 3: Rename Frolf Bot's Lich King

To avoid confusion with the master Lich King:

```bash
cd frolf-bot-infrastructure
mv the-lich-king multi-tenant-guilds
```

Update `app-frolf-bot.yaml` to point to `multi-tenant-guilds` instead of `the-lich-king`.

## Phase 4: Deploy The Lich King

```bash
# Apply The Lich King to your cluster
KUBECONFIG=~/.kube/config-oci kubectl apply -f all-infrastructure/argocd-applications/the-lich-king.yaml

# Watch the magic happen
KUBECONFIG=~/.kube/config-oci kubectl get applications -n argocd -w
```

## Phase 5: Update Sealed Secrets

Generate new sealed secrets for OCIR pull secret:

```bash
cd all-infrastructure

# Create OCIR pull secret
kubectl create secret docker-registry ocir-pull-secret \
  --docker-server=iad.ocir.io \
  --docker-username="$(cat ~/.oci/tenancy_namespace.txt)/oracleidentitycloudservice/$(cat ~/.oci/oci_username.txt)" \
  --docker-password="$(cat ~/.oci/github-ocir-token.txt)" \
  --docker-email="$(cat ~/.oci/oci_username.txt)" \
  --namespace resume \
  --dry-run=client -o yaml | \
  kubeseal --controller-name sealed-secrets --controller-namespace kube-system \
  -o yaml > sealed-secrets/ocir-pull-secret-resume-sealed.yaml

# Same for frolf-bot namespace
kubectl create secret docker-registry ocir-pull-secret \
  --docker-server=iad.ocir.io \
  --docker-username="$(cat ~/.oci/tenancy_namespace.txt)/oracleidentitycloudservice/$(cat ~/.oci/oci_username.txt)" \
  --docker-password="$(cat ~/.oci/github-ocir-token.txt)" \
  --docker-email="$(cat ~/.oci/oci_username.txt)" \
  --namespace frolf-bot \
  --dry-run=client -o yaml | \
  kubeseal --controller-name sealed-secrets --controller-namespace kube-system \
  -o yaml > sealed-secrets/ocir-pull-secret-frolf-sealed.yaml

# Commit sealed secrets
git add sealed-secrets/
git commit -m "Add OCIR pull secrets for all namespaces"
git push
```

## Phase 6: Verify Everything Works

```bash
# Check platform resources deployed
KUBECONFIG=~/.kube/config-oci kubectl get applications -n argocd

# Check observability stack
KUBECONFIG=~/.kube/config-oci kubectl get pods -n observability

# Check resume app
KUBECONFIG=~/.kube/config-oci kubectl get pods -n resume

# Check frolf-bot app
KUBECONFIG=~/.kube/config-oci kubectl get pods -n frolf-bot

# Check ArgoCD UI shows everything green
# https://localhost:8081
```

## What Each Repo Owns After Migration

### all-infrastructure

**Owns:** Entire cluster platform and orchestration

- ArgoCD itself
- All cluster-wide resources (Sealed Secrets, cert-manager, ingress)
- Observability stack (Grafana, Loki, Tempo, Mimir)
- Shared services (NATS)
- The Lich King (master ApplicationSet)
- Terraform for OCI infrastructure
- Ansible for cluster bootstrap

### resume-infrastructure

**Owns:** Resume application manifests only

- `resume-app-manifests/backend/`
- `resume-app-manifests/frontend/`
- `resume-app-manifests/nginx-ingress.yaml`
- Application-specific secrets (sealed)
- (Optional) Terraform for resume-specific cloud resources

### frolf-bot-infrastructure

**Owns:** Frolf bot application manifests only

- `frolf-bot-app-manifests/backend/`
- `frolf-bot-app-manifests/discord/`
- `multi-tenant/` (guild configs)
- `multi-tenant-guilds/` (guild ApplicationSet, formerly the-lich-king)
- Application-specific secrets (sealed)
- Local dev tooling (Tiltfile, Makefile)

## Benefits of This Structure

✅ **Single source of truth** for platform infrastructure
✅ **No conflicts** - only one Grafana, one cert-manager, etc.
✅ **Shared observability** - all apps report to same monitoring stack
✅ **Clear ownership** - platform team owns all-infrastructure, app teams own their app repos
✅ **Easy onboarding** - new apps just need ApplicationSet in all-infrastructure
✅ **GitOps native** - The Lich King watches all repos, auto-syncs changes
✅ **Multi-tenant friendly** - Frolf bot's guild pattern preserved

## Rollback Plan

If migration fails, you can:

1. Delete The Lich King: `kubectl delete applicationset the-lich-king -n argocd`
2. Re-apply old Overmind/Lich King from original repos
3. Keep both running (with namespace isolation) while debugging

## Next Steps After Migration

1. Update CI/CD pipelines to push images to OCIR
2. Configure ArgoCD Image Updater for automated deployments
3. Set up RBAC for app teams (restrict resume team to resume namespace)
4. Document deployment workflows for each app team
5. Set up Grafana dashboards for each application
6. Configure alerting rules in Mimir/Alloy
