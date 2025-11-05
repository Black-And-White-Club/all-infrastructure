# Observability Architecture Decision

## Context

**Resume** uses simple Prometheus (metrics only)
**Frolf-bot** uses advanced observability (Mimir, Loki, Tempo, Alloy)

## Decision

**Hybrid approach**: Shared Grafana, separate backends

```
┌─────────────────────────────────────────────┐
│      observability namespace                │
│                                              │
│  ┌────────────────────────────────────┐    │
│  │         Grafana (shared)            │    │
│  │                                     │    │
│  │  Datasources:                      │    │
│  │  • Resume Prometheus               │    │
│  │  • Frolf Mimir (metrics)           │    │
│  │  • Frolf Loki (logs)               │    │
│  │  • Frolf Tempo (traces)            │    │
│  └────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
              │
              │ Queries data from ↓
         ┌────┴─────┐
         │          │
    ┌────▼───┐  ┌──▼──────────────┐
    │ resume │  │ frolf-bot        │
    │        │  │                  │
    │  📊    │  │  📊 Mimir        │
    │  Prom  │  │  📝 Loki         │
    │        │  │  🔍 Tempo        │
    │        │  │  🔄 Alloy        │
    └────────┘  └──────────────────┘
```

## Why This Works

### ✅ Resume Benefits

- Simple Prometheus (lightweight, proven)
- No unnecessary complexity
- Lower resource usage
- Faster to understand and maintain

### ✅ Frolf-bot Benefits

- Full observability stack (distributed tracing, log aggregation)
- Mimir for long-term metrics storage
- Loki for structured log queries
- Tempo for distributed tracing
- Alloy for flexible telemetry collection

### ✅ Shared Benefits

- **One Grafana UI** for both apps (unified dashboards)
- **Cross-app correlation** possible (if needed)
- **Resource efficient** (one Grafana vs two)
- **Consistent UX** for operators

### ✅ Architectural Benefits

- **Separation of concerns**: Each app owns its data backend
- **Independent scaling**: Resume Prometheus vs Frolf Mimir scale independently
- **No forced complexity**: Resume doesn't need what it won't use
- **Future-proof**: Easy to add more apps with their own backends

## What Lives Where

### all-infrastructure (Platform)

```yaml
charts/grafana/values.yaml:
  datasources:
    - Resume Prometheus (resume.svc.cluster.local)
    - Frolf Mimir (frolf-bot.svc.cluster.local)
    - Frolf Loki (frolf-bot.svc.cluster.local)
    - Frolf Tempo (frolf-bot.svc.cluster.local)
```

### resume-infrastructure (App)

```
resume-app-manifests/
├── frontend/
├── backend/
└── prometheus/   # Simple Prometheus deployment
    ├── deployment.yaml
    ├── service.yaml
    └── configmap.yaml
```

### frolf-bot-infrastructure (App)

```
frolf-bot-app-manifests/
├── backend/
├── discord/
└── observability/  # Full stack
    ├── mimir/
    ├── loki/
    ├── tempo/
    └── alloy/
```

## Grafana Configuration

Datasources are pre-configured in Grafana Helm values:

```yaml
datasources:
  - name: Resume Prometheus
    type: prometheus
    url: http://prometheus.resume.svc.cluster.local:9090

  - name: Frolf Mimir
    type: prometheus
    url: http://mimir-nginx.frolf-bot.svc.cluster.local/prometheus
    isDefault: true # Default to advanced metrics

  - name: Frolf Loki
    type: loki
    url: http://loki-gateway.frolf-bot.svc.cluster.local

  - name: Frolf Tempo
    type: tempo
    url: http://tempo.frolf-bot.svc.cluster.local:3100
```

## Dashboard Organization

Grafana dashboard folders:

- **Resume/** - Simple app metrics (requests, latency, errors)
- **Frolf Bot/** - Advanced dashboards (traces, logs, distributed metrics)

## Migration Path

1. ✅ **all-infrastructure**: Deploy only Grafana (done)
2. ⏳ **resume-infrastructure**: Keep existing Prometheus
3. ⏳ **frolf-bot-infrastructure**: Keep existing observability stack (Mimir, Loki, Tempo, Alloy)
4. ⏳ **Configure Grafana datasources** pointing to both
5. ⏳ **Create dashboards** in respective folders

## Alternative Considered (and Rejected)

### ❌ Full Shared Stack

- Would force Resume to use Mimir/Loki/Tempo
- Over-engineered for Resume's needs
- Wastes resources on unused features

### ❌ Completely Separate

- Two Grafana instances
- Duplicate resource usage
- Harder to correlate across apps
- Inconsistent UX

### ✅ Hybrid (Chosen)

- Best of both worlds
- Shared visualization, separate backends
- Right-sized for each app's complexity
