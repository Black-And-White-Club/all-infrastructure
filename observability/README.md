# Observability

This directory contains Helm values and scaffolding for the shared monitoring stack. The idea is a single Prometheus/Grafana/Loki/Tempo stack that scrapes both project namespaces and exposes dashboards scoped by team.

Files here are intentionally small examples; customize them to match your chart versions and desired persistence/retention.
