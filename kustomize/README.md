Kustomize conventions for this repository

Guiding principles:

- Keep Kustomize directories simple: one directory per app, no overlays.
- Do NOT set `namespace:` in `kustomization.yaml`. ArgoCD `Application.destination.namespace` controls the target namespace.
- Use `configMapGenerator` freely; Kustomize will rewrite references in resources included in the same kustomization.
- Add SealedSecrets (already sealed) as raw YAML under the app `kustomize/<app>/` and include them in `resources:` — do not attempt to use `secretGenerator` for sealed secrets.
- Keep `images:` in `kustomization.yaml` so ArgoCD Image Updater can write back tags when using the kustomize write-back strategy.

How to add a new app:

1. Create `kustomize/<app>/` with your resource YAMLs (Deployment, Service, ConfigMaps, SealedSecrets).
2. Add a `kustomization.yaml` listing the resources and an `images:` block for the images.
3. Add an `apps/<app>-app.yaml` ArgoCD Application that points to `kustomize/<app>`.

Note about ConfigMaps:
Kustomize `configMapGenerator` appends a hash to generated ConfigMap names to force pod restarts on config changes. Do not hardcode the hashed name in your Deployment; as long as the Deployment is included as a `resource:` in the same `kustomization.yaml`, Kustomize will update the Deployment to reference the generated name.
