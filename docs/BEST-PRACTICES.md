# 2025 Best Practices Implementation

## What We Built

A **production-ready GitOps architecture** following industry best practices:

### The Lich King Architecture

```
The Lich King (Root Application)
│
├── bootstrap/ (directory of ApplicationSets)
│   │
│   ├── 00-platform-base.yaml (Wave 0-2)
│   │   ├── Sealed Secrets (kube-system)
│   │   ├── Cert-Manager (cert-manager)
│   │   └── Cluster Resources (namespaces, storage)
│   │
│   ├── 01-platform-observability.yaml (Wave 10)
│   │   └── Grafana (observability namespace)
│   │       ├── Datasource: Resume Prometheus
│   │       └── Datasource: Frolf Mimir/Loki/Tempo
│   │
│   ├── 02-platform-shared-services.yaml (Wave 15)
│   │   └── ApplicationSet → shared-services namespace
│   │       └── NATS (Postgres instances are deployed per-app via Helm)
│   │
│   ├── 10-app-resume.yaml (Wave 20)
│   │   └── Application → resume namespace
│   │       ├── Frontend
│   │       ├── Backend
│   │       └── Prometheus
│   │
│   └── 11-app-frolf-bot.yaml (Wave 20-21)
│       ├── Backend → frolf-bot namespace
│       ├── Discord → frolf-bot namespace
│       ├── Mimir/Loki/Tempo/Alloy → frolf-bot namespace
│       └── Guilds ApplicationSet → per-guild namespaces
```

## Best Practices Applied

### ✅ 1. ApplicationSets for Scalable Patterns

**Observability Stack** (ApplicationSet):

- One template, five deployments (Grafana, Loki, Tempo, Mimir, Alloy)
- Explicit list generator (clear what's deployed)
- All share same namespace (`observability`)

**Shared Services** (ApplicationSet):

- NATS (Postgres instances are deployed per-app via Helm)
- Same pattern for consistency

**Frolf Bot Guilds** (ApplicationSet in frolf-bot repo):

- Multi-tenant pattern preserved
- Each guild gets own namespace

### ✅ 2. Explicit List Generators

```yaml
generators:
  - list:
      elements:
        - name: grafana
          chart: grafana
          chartVersion: "8.7.3"
```

**Why**: Clear, reviewable, deterministic. No surprises.

### ✅ 3. Proper Namespace Isolation

| Namespace         | Contents                                                    | Shared?                       |
| ----------------- | ----------------------------------------------------------- | ----------------------------- |
| `kube-system`     | Sealed Secrets                                              | ✅ Cluster-wide               |
| `cert-manager`    | Cert-Manager                                                | ✅ Cluster-wide               |
| `observability`   | **Grafana only** (shared visualization)                     | ✅ Shared visualization layer |
| `shared-services` | NATS                                                        | ✅ Operators (not instances)  |
| `resume`          | Resume app + **Prometheus** (simple metrics)                | ❌ Resume only                |
| `frolf-bot`       | Frolf app + **Mimir/Loki/Tempo/Alloy** (full observability) | ❌ Frolf only                 |
| `guild-*`         | Per-guild deployments                                       | ❌ Guild-specific             |

**Observability Architecture**:

- **Shared Grafana** in `observability` namespace (one UI for all apps)
- **Resume** uses simple Prometheus in `resume` namespace
- **Frolf-bot** uses full stack (Mimir, Loki, Tempo, Alloy) in `frolf-bot` namespace
- Grafana datasources point to both backends

**Why this design**:

- ✅ Resume stays simple (just Prometheus for metrics)
- ✅ Frolf-bot has advanced observability (logs, traces, distributed metrics)
- ✅ Shared Grafana for unified dashboards
- ✅ No forced complexity on simpler apps
- ✅ Independent scaling per app's needs

### ✅ 4. Root Application (not ApplicationSet)

**The Lich King** is an `Application` pointing to `bootstrap/` directory.

**Why**: Simpler than ApplicationSet-of-ApplicationSets. The bootstrap directory contains the actual ApplicationSets.

### ✅ 5. Sync Waves for Ordering

- **Wave 0-2**: Foundation (Sealed Secrets, Cert-Manager, cluster resources)
- **Wave 10**: Observability (needs storage from Wave 2)
- **Wave 15**: Shared services (needs observability metrics)
- **Wave 20**: Applications (need all infrastructure ready)
- **Wave 21**: Multi-tenant guilds (need frolf-bot backend)

### ✅ 6. Multi-Source Applications

```yaml
sources:
  - repoURL: https://grafana.github.io/helm-charts # Helm chart
    chart: grafana
  - repoURL: https://github.com/.../all-infrastructure # Values file
    ref: values
    path: charts/grafana/values.yaml
```

**Why**: Chart version locked, but values customizable in your repo.

## GitOps Workflow

### Bootstrap (one-time)

```bash
cd /Users/jace/Documents/GitHub/all-infrastructure
git add .
git commit -m "Add The Lich King GitOps architecture"
git push

./scripts/bootstrap-lich-king.sh
```

### Day-to-Day Changes

```bash
# Update a Helm value
vim charts/grafana/values.yaml

# Commit and push
git add charts/grafana/values.yaml
git commit -m "Increase Grafana memory limits"
git push

# ArgoCD auto-syncs within ~3 minutes
```

### Adding a New Platform Service

```bash
# Add to bootstrap ApplicationSet
vim argocd-applications/bootstrap/01-platform-observability.yaml

# Add to generators list
- name: prometheus
  chart: prometheus
  chartVersion: "25.27.0"
  repoURL: https://prometheus-community.github.io/helm-charts

# Create values file
mkdir charts/prometheus
vim charts/prometheus/values.yaml

# Commit and push
git add .
git commit -m "Add Prometheus to observability stack"
git push
```

## What's Different from Before

| Before                          | After (Best Practice)           |
| ------------------------------- | ------------------------------- |
| Separate infra repos            | Unified platform repo           |
| Manual ApplicationSet structure | App-of-Apps pattern             |
| Mixed namespaces                | Clear namespace strategy        |
| Hardcoded Applications          | ApplicationSets with generators |
| No sync waves                   | Explicit ordering via waves     |
| Single repo for everything      | Platform vs app separation      |

## What You Should Do Next

1. ✅ **Commit and push all-infrastructure**
2. ✅ **Run bootstrap script**
3. ✅ **Watch ArgoCD deploy everything**
4. ⏳ **Copy detailed observability configs** from frolf-bot-infrastructure
5. ⏳ **Simplify resume/frolf repos** (remove platform resources)
6. ⏳ **Generate OCIR pull secrets** and seal them
7. ⏳ **Update CI/CD** to push to OCIR

## Why This is Best Practice

✅ **Declarative**: Everything in Git
✅ **Auditable**: Git history = deployment history
✅ **Recoverable**: Re-apply The Lich King = rebuild cluster
✅ **Scalable**: Add apps with one ApplicationSet entry
✅ **Reviewable**: PRs show exactly what changes
✅ **Automated**: No manual kubectl after bootstrap
✅ **Multi-tenant ready**: Frolf guilds pattern preserved
✅ **Resource efficient**: Shared observability = lower costs
