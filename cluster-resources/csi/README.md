# OCI CSI Driver (GitOps managed)

This directory contains manifests for installing the Oracle Cloud Infrastructure (OCI) Block Storage CSI driver via GitOps (ArgoCD). The driver is required for the `oci-block-storage` StorageClass to provision volumes automatically.

## Current Version

**v1.33.0** - pulled directly from Oracle's official GitHub releases.

- GitHub: https://github.com/oracle/oci-cloud-controller-manager
- CSI Docs: https://github.com/oracle/oci-cloud-controller-manager/blob/master/container-storage-interface.md

## Structure

```
oci-csi-driver/
├── kustomization.yaml   # References remote YAMLs from Oracle + local storage class
└── storage-class.yaml   # oci-bv and oci-block-storage StorageClasses
```

## Prerequisites

Before the CSI driver can provision volumes, you need to create an OCI credentials secret:

```bash
# Create provider config file (see manifests/provider-config-example.yaml in the OCI repo)
cat > /tmp/oci-volume-provisioner-config.yaml <<EOF
auth:
  region: us-ashburn-1
  tenancy: ocid1.tenancy.oc1..xxxxx
  user: ocid1.user.oc1..xxxxx
  key: |
    -----BEGIN RSA PRIVATE KEY-----
    ...your OCI API private key...
    -----END RSA PRIVATE KEY-----
  fingerprint: xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx
  # Optional: passphrase if your key is encrypted
compartment: ocid1.compartment.oc1..xxxxx
EOF

# Create the secret (dry-run for sealing)
kubectl create secret generic oci-volume-provisioner \
  -n kube-system \
  --from-file=config.yaml=/tmp/oci-volume-provisioner-config.yaml \
  --dry-run=client -o yaml > /tmp/oci-volume-provisioner-secret.yaml

# Seal it
kubeseal --controller-namespace kube-system --controller-name sealed-secrets \
  --format=yaml < /tmp/oci-volume-provisioner-secret.yaml \
  > cluster-resources/sealed-secrets/oci-volume-provisioner-sealed.yaml

# Clean up plaintext
rm /tmp/oci-volume-provisioner-config.yaml /tmp/oci-volume-provisioner-secret.yaml
```

Add `oci-volume-provisioner-sealed.yaml` to the sealed-secrets kustomization.yaml and commit.

## ArgoCD Application

The driver is deployed via `argocd/platform/oci-csi-driver.yaml` which references this directory.

## Upgrading

To upgrade to a newer version:

1. Check releases: https://github.com/oracle/oci-cloud-controller-manager/releases
2. Update the version in `oci-csi-driver/kustomization.yaml`
3. Commit and let ArgoCD sync

## Troubleshooting

Check CSI pods are running:

```bash
kubectl -n kube-system get po | grep csi-oci
```

Check PVC events if volumes aren't provisioning:

```bash
kubectl describe pvc <pvc-name> -n <namespace>
```
