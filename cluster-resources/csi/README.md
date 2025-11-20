# OCI CSI driver (GitOps managed)

This directory contains manifests and examples for installing the Oracle Cloud Infrastructure (OCI) Block Storage CSI driver via GitOps (ArgoCD). The driver is required for the `oci-block-storage` StorageClass to provision volumes automatically.

## Overview

- Do not commit secrets into the repository. Use Sealed Secrets or SOPS for credentials used by the driver.
- Install the CSI driver components (Controller and Node components) as a Helm release or manifest set.
- Add a small ArgoCD Application in `argocd-applications/` to manage the lifecycle.

## What to add here

- `oci-csi-values.yaml` — Helm values referencing a `SealedSecret` holding OCI credentials.
- `oci-csi-manifests/` — If you prefer to include raw manifests.
- `README.md` — This file explains how to deploy and the required secrets.

Quick install (manual, not GitOps) as an example:

```bash
# Add and update the Helm repo (example repo, verify the correct OCI one):
helm repo add oci-csi-driver https://oracle.github.io/oci-csi-driver/charts
helm repo update

# Install the driver (example values file path and release name; this is manual only):
helm install oci-csi-driver oci-csi-driver/oci-block-csi-driver \
  --namespace kube-system \
  --create-namespace \
  -f values.yaml
```

## GitOps approach

1. Add manifests/helm chart values in this directory.
2. Add an ArgoCD Application that references this directory (see `argocd-applications/platform/99-oci-csi-driver.yaml` example).
3. Add the OCI secret as a SealedSecret in `cluster-resources/sealed-secrets/` so ArgoCD can create it in `kube-system`.

## Note on credentials

The driver requires an OCI principal with sufficient permissions to create block volumes (overview of permissions and example policies will vary by tenancy setup). Use a SealedSecret to store credentials and avoid committing them to Git.

See also: `MIGRATION-OCI.md` and the documentation for your OCI CSI driver for exact helm chart names/values.
