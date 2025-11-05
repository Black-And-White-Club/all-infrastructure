# The Lich King - GitOps Bootstrap Guide

## Overview

**The Lich King** is the master ApplicationSet that manages all platform and application resources on the OCI Kubernetes cluster using GitOps principles.

This folder contains ArgoCD Applications and ApplicationSets that deploy cluster-level resources and platform components.

## Architecture

```
The Lich King (ApplicationSet)
│
├── Wave 0: Platform Base
│   ├── Sealed Secrets (Helm chart)
│   └── Cluster Resources (namespaces, storage classes, PVs)
│
├── Wave 1: Observability
│   └── Grafana (shared visualization for resume + frolf-bot)
│
├── Wave 2: Shared Services
│   ├── Postgres Operator (CloudNativePG)
│   └── NATS (JetStream enabled)
│
└── Wave 10: Applications
    ├── Resume (→ resume-infrastructure repo)
    │   └── Includes: Prometheus in resume namespace
    └── Frolf Bot (→ frolf-bot-infrastructure repo)
        └── Includes: Mimir/Loki/Tempo/Alloy in frolf-bot namespace
```

## Bootstrap Process

### Step 1: Apply The Lich King

```bash
cd /Users/jace/Documents/GitHub/all-infrastructure
./scripts/bootstrap-lich-king.sh
```

### Step 2: Watch Deployment

```bash
# Watch Applications
KUBECONFIG=~/.kube/config-oci kubectl get applications -n argocd -w

# Access ArgoCD UI
KUBECONFIG=~/.kube/config-oci kubectl port-forward svc/argocd-server -n argocd 8081:443
# Open https://localhost:8081
```

## How GitOps Works

1. **Update files** in this repo (charts/, cluster-resources/, argocd-applications/)
2. **Commit and push** to GitHub
3. **ArgoCD auto-syncs** within ~3 minutes

## File Structure

- `the-lich-king.yaml` - Master ApplicationSet orchestrator
- `platform/` - Platform ApplicationSets (infrastructure)
- `applications/` - Application bootstrappers (point to app repos)

See `/docs/MIGRATION-PLAN.md` for detailed architecture and migration guide.
