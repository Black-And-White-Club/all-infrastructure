# Service Account module (compatibility)

This module is a compatibility shim that mirrors the interface and resource addresses used by the `service-account` module in the project repositories. It currently creates the same GCP service account resources so you can switch the module source without causing resource moves or deletions.

Next steps:

- Keep the same variable names and outputs while you migrate other modules.
- Later, implement an OCI equivalent and plan a resource migration strategy (create new OCI identities or switch to managed identities as appropriate).
