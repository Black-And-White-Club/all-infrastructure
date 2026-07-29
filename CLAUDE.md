# all-infrastructure — GitOps Platform

## What this repo does

Provisions cloud infra (Terraform), bootstraps Kubernetes (Ansible), and manages all workloads via ArgoCD GitOps (app-of-apps pattern). **Never `kubectl patch` manually** — all changes go through Git.

## When to look here

Deploying a new service, changing K8s manifests, updating Helm chart values, adding/rotating secrets (SOPS+age), modifying ingress, changing observability config, running DB migrations in cluster.

## GitOps workflow

```
Terraform → Ansible → argocd/root-app.yaml (the-lich-king)
  → syncs platform/, observability/, apps/, cluster-resources/
  → applies kustomize/overlays/production/
```

ArgoCD Image Updater commits new image digests directly into `kustomize/<app>/overlays/production/` on the configured write-back branch. Verify the target file before changing image-update behavior.

## Folder map

| Path | Purpose |
|------|---------|
| `terraform/` | Cloud infra (OCI): compute, networking, storage, IAM. Modules in `terraform/modules/`. |
| `ansible/playbooks/` | Cluster bootstrap: `bootstrap-argocd.yml`, `setup-storage.yml`, `setup-local-k8s.yml` |
| `argocd/` | GitOps control plane. `root-app.yaml` is the app-of-apps root. |
| `argocd/apps/` | App definitions (frolf-backend, pwa, discord, nats, postgres) |
| `argocd/platform/` | Platform services (cert-manager, nginx, sealed-secrets, argo-rollouts) |
| `argocd/observability/` | Observability stack (grafana, loki, tempo, mimir, alloy) |
| `argocd/projects/` | RBAC |
| `kustomize/<app>/` | Per-app manifests: `base/` + `overlays/production/`. Image Updater writes here. |
| `cluster-resources/` | Cluster-scoped: namespaces, StorageClasses, CRDs, NetworkPolicies, secret references |
| `charts/` | Helm values for platform services |
| `scripts/` | `bastion-connect.sh`, `recreate-postgres-pvc.sh`, `smoke-frolf-backend-migrations.sh` (dry-run by default), `validate-frolf-backend-migration-hook.sh`, `generate-nats-auth-keys.sh` |
| `docs/` | `BEST-PRACTICES.md`, `KUBESPRAY.md`, `OBSERVABILITY-ARCHITECTURE.md`, `MIGRATION-PLAN.md` |
| `external/` | Git submodules — **read-only, do not edit** (kubespray only) |
| `config/` | Environment configs and secret templates |

## Add a new app to the platform — checklist

1. Author manifests in `kustomize/<app>/base/` (Deployment, Service, Ingress).
2. Create `kustomize/<app>/overlays/production/` with thin patches (image, env, replicas).
3. If the app needs secrets, add SOPS-encrypted entries in `all-infrastructure-secrets/` and reference by name (never inline).
4. Add an ArgoCD `Application` under `argocd/apps/`.
5. Register the app in `argocd/root-app.yaml` (or the relevant child app-of-apps).
6. Verify locally: `kustomize build kustomize/<app>/overlays/production` and `kube-linter lint .`.
7. Commit, push, watch ArgoCD sync. Don't `kubectl apply` directly.

## Secrets: SOPS + age + KSOPS → SealedSecrets

Encrypted secrets live in the sibling repo `all-infrastructure-secrets/` (loaded as a kustomize generator via KSOPS). Two layers are in play: the files are SOPS+age-encrypted **SealedSecret** manifests — KSOPS decrypts them at ArgoCD render time (the `cluster-sealed-secrets` app syncs that repo), and the in-cluster Bitnami sealed-secrets controller (`argocd/platform/sealed-secrets-controller.yaml`) then unseals them into plain `Secret`s. Both the SOPS age key and the sealed-secrets sealing key matter for recovery.

**Encrypt a new secret:**
1. Drop plaintext YAML on disk.
2. `sops --encrypt --in-place --age <recipient-from-.sops.yaml> path/to/secret.sops.yaml`.
3. Reference the file from a `kustomization.yaml` `generators:` entry that loads `ksops-generator.yaml`.
4. Commit the encrypted file. **Never** commit plaintext.

**Past gotchas (don't repeat):**
- KSOPS Helm field is `env`, **not** `extraEnv` — wrong field silently breaks decryption.
- KSOPS binary must match cluster arch — wrong arch (`x86_64` vs `arm64`) crashes the init container with a confusing error.
- Verify `.sops.yaml` `creation_rules` cover the file path before encrypting; otherwise `sops` writes plaintext.

## Terraform module conventions

- Reusable modules live in `terraform/modules/`.
- Promote inline resource blocks to a module when used in 2+ envs.
- Pin provider versions; run `terraform fmt && terraform validate` before commit.
- `terraform plan` against the relevant workspace before any apply.

## K3s vs production K8s

- K3s (homelab / `emerald-dream`) is the dev target — some manifests assume K3s defaults (Traefik, local-path provisioner).
- Production overlays live under `kustomize/<app>/overlays/production/` and assume the OCI cluster (nginx ingress, OCI block storage class).
- When adding cluster-resource dependencies, check both targets.

## Third-party: Kubespray

`external/kubespray/` is a submodule of `kubernetes-sigs/kubespray`. **Do not edit.** See `docs/KUBESPRAY.md` for upgrade procedure.

## Dev / CI commands

```bash
kustomize build kustomize/<app>/overlays/production
helm template <chart> charts/<chart>/values.yaml
kube-linter lint .
terraform plan
ansible-playbook ansible/playbooks/<playbook>.yml --check
```

## Observability — metric naming

- **frolf-bot OTEL metrics export to Prometheus as `frolf_bot_<domain>_<name>_total`.** The exporter prepends the sanitized service name (`frolf-bot` → `frolf_bot_`) to the unprefixed base name defined in `frolf-bot-shared/observability/otel/metrics/<domain>/`. So a Grafana panel querying the **base** name (e.g. `business_referral_joins_total`) silently shows NO data — use the prefixed series (`frolf_bot_business_referral_joins_total`). `system-mapper list_entities kind=metric` and the Go source show the **unprefixed base**, which is NOT the runtime series name. When adding a panel, copy a neighbor and match its `frolf_bot_*` form.

## Probes, sidecars & Service ports — gotchas (verified in prod 2026-07-22)

- **A sidecar's failing readiness probe removes the WHOLE pod from every Service** — a crash-looping metrics exporter took prod NATS offline (PWA-wide NatsError) while the NATS container itself was healthy. Never point an exporter sidecar's probes at `/metrics`: each hit triggers a full upstream scrape + multi-MB render, and under a small CPU limit CFS throttling stretches that past the probe's 1s timeout → liveness kill-loop. Use `tcpSocket` probes for exporters (prometheus-nats-exporter serves NO other HTTP path — its `-healthz` flag selects which NATS endpoint to scrape; exporter-side `/healthz` 404s). Diagnostic tell for throttling: `kubectl exec <pod> -c <container> -- cat /sys/fs/cgroup/cpu.stat` — high `nr_throttled/nr_periods` (the outage showed 65%). Fixed in `9d1a4aaf` (charts/nats/values.yaml has the in-place rationale).
- **Never add a Helm `extraPorts` entry whose `port` duplicates a chart's built-in Service port.** ServicePort's strategic-merge key is `port`; a duplicate key wedges ArgoCD with `failed to construct strategic merge patch ... doesn't match $setElementOrder`. The error is DELAYED — it only fires when a later change first forces a patch on that list, so the bad entry can sit silent for weeks (alloy `internal-http:12345` duplicated built-in `http-metrics:12345`; surfaced only when `otlp-http-web:4319` was added). Render the chart (`helm template ... -f charts/<x>/values.yaml`) and check the Service for duplicate port numbers before adding entries. Fixed in `e715f2a5`.

## Self-check before declaring done

- `kustomize build` and `kube-linter lint .` succeed for changed overlays.
- For Terraform: `terraform plan` reviewed; no unintended diffs.
- For secrets: encrypted file committed (no plaintext); KSOPS generator referenced.
- For app additions: ArgoCD Application registered + root app references it; sync observed in ArgoCD UI.
- GitOps discipline: no `kubectl apply` / `kubectl patch` / `kubectl edit` commands run.
