# Migration choice: quick copy (no history)

Chose approach: Quick copy — starting fresh without preserving Git history.

Files that were moved into this repository in the initial quick-copy step:

- `ansible/playbooks/*` (cluster bootstrap, storage, argocd, monitoring)
- `ansible/inventory` and `ansible/requirements.yml`
- `cluster-resources/*` (namespaces, storage-classes, PV templates, resource quota)
- `observability/*` (app descriptors used by ApplicationSets)
- `argocd-applications/*` (platform-level Application / ApplicationSet manifests)

Notes & next steps:

- Terraform modules were not moved in this quick-copy. If you want to consolidate infrastructure modules here, we can copy them next.
- Update provider-specific values (GCP/OCI) and StorageClass provisioners before applying these manifests to a real cluster.
- Consider whether sealed-secrets controller and postgres operator should be centralized or left to project repos.
