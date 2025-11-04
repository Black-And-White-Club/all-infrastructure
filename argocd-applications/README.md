# ArgoCD applications (platform)

This folder contains ArgoCD `Application` manifests that deploy cluster-level resources and platform components from this repository.

If ArgoCD is installed in the cluster (recommended via Helm), these applications will be reconciled by ArgoCD and will apply the manifests in this repo.

Tip: Keep project-specific `ApplicationSet`/`Application` manifests in the project repositories so teams retain control over application deployments.
