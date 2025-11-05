# Postgres operator

This folder holds values and examples for installing a Postgres operator and for creating per-project Postgres clusters.

Recommendations

- Install a single operator (CloudNativePG, Crunchy, or Zalando) in the platform namespace and create one DB cluster per project.
- Use project-specific `storageClassName` values so the physical storage can be separated.

Example CRs for each project should be stored in their respective project repositories (`frolf-bot-infrastructure` and `resume-infrastructure`) and reference the storage classes defined in `cluster-resources/`.
