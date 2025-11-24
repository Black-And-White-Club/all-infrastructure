# Kustomize conventions for this repository

Each app in `kustomize/` now follows a **base + production overlay** layout so the same manifests can be referenced by multiple environments in the future while keeping the production build explicit for Argo CD.

```
├── resume-backend/
│   ├── base/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── overlays/
│       └── production/
│           └── kustomization.yaml (resources: ["../../base"])
├── frolf-backend/
│   └── …
└── …
```

## Base kustomization rules

- Keep the actual `Deployment`, `Service`, `StatefulSet`, `ConfigMap`, `SealedSecret`, and supporting YAMLs inside the `base/` directory alongside a single `kustomization.yaml`.
- The `base/kustomization.yaml` is where you declare `resources:`, `images:`, `labels:`, and any `configMapGenerator` blocks. This is the document Argo CD Image Updater mutates, so keep the image names there.
- **Do not set `namespace:` in the base kustomization.** The namespace comes from the Argo CD `Application.destination` so the same base can deploy anywhere.
- Any sealed secrets you need should live in the base `resources:` list. Do not try to use `secretGenerator` for sealed secrets; they must remain literal YAML so that kubeseal can validate them.

## Production overlays

- Every Argo CD app currently points at `kustomize/<app>/overlays/production`. The production overlay simply references `../../base` and can be extended later if the environment requires extra config.
- Keep overlays thin: reference the base, add patches only when you need to override fields for that environment, and avoid duplicating `resources` lists.

## ConfigMapGenerator gotcha

- Kustomize appends a hash to generated ConfigMap names. Do **not** hardcode the hashed name in your workload YAML; include the generator in the same base kustomization so Kustomize rewrites the reference automatically.

## Summary

- Build the canonical manifest inside the base directory, keep overlays small, and always deploy the `production` overlay via Argo CD. This keeps the repository organized while leaving room for new overlays later.
