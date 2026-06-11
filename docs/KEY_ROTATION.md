# Key Rotation Procedures

This document covers rotation procedures for all secrets managed by this repo.
All changes go through the GitOps pipeline (commit → ArgoCD sync). Never
patch secrets manually via kubectl.

---

## Stripe secret-key rotation

**Procedure: create new key, reseal, rolling restart, revoke old.**

1. In the Stripe Dashboard, create a new restricted API key with the same
   permissions as the current `STRIPE_SECRET_KEY`. Do not revoke the old key yet.

2. Decrypt the current sealed backend secrets in the private repo:
   ```bash
   cd /path/to/all-infrastructure-secrets
   sops --decrypt --in-place sealed-backend-secrets.sops.yaml
   ```

3. Seal in the new key using the patch script:
   ```bash
   STRIPE_SECRET_KEY="sk_live_<new_key>" \
   /path/to/all-infrastructure/cluster-resources/sealed-secrets/patch-frolf-backend-secrets.sh \
     sealed-backend-secrets.sops.yaml
   ```

4. Re-encrypt and commit:
   ```bash
   sops --encrypt --in-place sealed-backend-secrets.sops.yaml
   git add sealed-backend-secrets.sops.yaml
   git commit -m "rotate: STRIPE_SECRET_KEY"
   ```

5. Push and wait for ArgoCD to sync and roll out the new Deployment. Verify the
   pod starts successfully (`kubectl rollout status deployment/frolf-bot-backend -n frolf-bot`).

6. Once the new pod is serving traffic, revoke the old key in the Stripe Dashboard.

---

## Stripe webhook-secret rotation

Stripe supports an **overlap window**: both the old and the new signing secret
are valid simultaneously for a short period, eliminating downtime.

1. In the Stripe Dashboard → Developers → Webhooks, roll the webhook signing
   secret. Stripe activates the new secret and keeps the old one valid for a
   brief overlap window (typically a few hours).

2. Follow steps 2–5 from the **Stripe secret-key rotation** section above,
   using `STRIPE_WEBHOOK_SECRET="whsec_<new_secret>"` (and/or
   `STRIPE_BILLING_WEBHOOK_SECRET` for the platform billing webhook).

3. After the rollout completes and you confirm events are processing correctly,
   the old secret is automatically invalidated by Stripe after the overlap window.

---

## Sealed-secrets controller key

The sealed-secrets controller auto-rotates its RSA key pair every **30 days**.
After rotation, existing SealedSecrets continue to decrypt with the old key
(the controller retains old keys). New SealedSecrets are encrypted with the
current active key.

A weekly backup CronJob archives the controller's private keys to OCI object
storage so they can be recovered after a cluster rebuild:

```
cluster-resources/platform-cronjobs/sealed-secrets-backup.yaml
```

To verify backup health, check the CronJob's last successful run:
```bash
kubectl get cronjob sealed-secrets-backup -n kube-system
kubectl get jobs -n kube-system --sort-by=.metadata.creationTimestamp | grep sealed-secrets-backup | tail -3
```

If a full cluster rebuild is needed and the backup is intact, restore the
controller keys before re-applying any SealedSecret manifests — otherwise
decryption will fail.

---

## age/SOPS key

The age private key used by ArgoCD's KSOPS plugin (stored in
`secrets/bootstrap/sops-age.yaml`) encrypts/decrypts all SOPS-managed secrets.
If this key is rotated:

1. Update the age private key in the cluster:
   ```bash
   kubectl create secret generic sops-age \
     --namespace argocd \
     --from-literal=age-key="<new_private_key>" \
     --dry-run=client -o yaml | kubectl apply -f -
   ```
2. Re-encrypt every `.sops.yaml` file in the private repo with the new recipient:
   ```bash
   # Update .sops.yaml creation_rules to reference the new public key.
   # Then re-encrypt each file:
   find /path/to/all-infrastructure-secrets -name "*.sops.yaml" \
     -exec sops --rotate --in-place {} \;
   ```
3. Commit all re-encrypted files and push.

---

## New docs cross-references

- Backup verification and restore drill: [POSTGRES_RESTORE_TEST.md](POSTGRES_RESTORE_TEST.md)
- Scaling and alerting graduation path: [SCALE_PLAYBOOK.md](SCALE_PLAYBOOK.md)
- Stripe cutover (five-key seal procedure): [sealed-secrets/README.md#stripe-cutover](../cluster-resources/sealed-secrets/README.md#stripe-cutover)
- Discord alerting webhook: [sealed-secrets/generate-grafana-alerting-discord-secret.sh](../cluster-resources/sealed-secrets/generate-grafana-alerting-discord-secret.sh)
