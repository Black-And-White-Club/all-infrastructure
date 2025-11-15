# Rotate DB credentials safely (resume-backend)

This is a short guide to rotating the database password for resume-backend without downtime.

Steps:

1. Generate new password and create a SealedSecret in the `resume-db` namespace (use the `generate-sealed-secrets.sh` to avoid mistakes):

```bash
./all-infrastructure/cluster-resources/sealed-secrets/generate-sealed-secrets.sh ./tmp
# This creates sealed files in ./tmp; copy sealed-<secret>.yaml into all-infrastructure/cluster-resources/sealed-secrets/ and commit
```

2. Apply the new `sealed-*.yaml` to the cluster via ArgoCD

   - This will create a new Kubernetes Secret in `resume-db` with the rotated password (but the DB instance itself still has the old password). The helm chart uses `existingSecret` so the password change alone doesn't change the DB credentials.

3. Change the DB password inside Postgres to the new value. You can do this by connecting to Postgres and running:

```sql
ALTER USER resume_user WITH PASSWORD '<new_password>';
```

4. Wait a moment for any existing DB connections to finish; a rolling restart of the backend may be required for the process to pick up a new `DATABASE_URL` if cached.

   ```bash
   kubectl -n resume-app rollout restart deployment resume-backend
   ```

5. Validate the application is healthy and able to connect to the DB with the new credentials.
   - Run the debug `psql` command described in `README.md` to verify connectivity.

Notes:

- The process steps are designed to avoid mid-flight failed connections. Rolling restart forces pods to pick up new secrets and re-connect using the new password.
- If you use connection pools or frameworks that cache connections, ensure you gracefully restart the application.
- Consider a health check or manual validation before and after rotation.
