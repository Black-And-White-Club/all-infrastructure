# Simplified Kustomize Structure (No Overlays)

**Goal**: Use Kustomize for organization and DRY principles, not for environment management. Single production setup.

---

## Directory Structure (Simplified)

```
all-infrastructure/
├── argocd-applications/
│   ├── the-lich-king.yaml                 # Root orchestrator
│   ├── cluster-resources-appset.yaml
│   ├── infrastructure-appset.yaml
│   ├── observability-appset.yaml
│   ├── sealed-secrets-appset.yaml
│   └── apps-appset.yaml
│
├── apps/                                   # App manifests (point to Kustomize)
│   ├── resume-backend-app.yaml
│   ├── resume-frontend-app.yaml
│   ├── resume-postgres-app.yaml
│   ├── frolf-backend-app.yaml
│   ├── frolf-discord-app.yaml
│   ├── frolf-postgres-app.yaml
│   └── frolf-nats-app.yaml
│
├── kustomize/                              # Kustomize-based manifests
│   ├── resume-backend/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   ├── resume-frontend/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── ingress.yaml
│   ├── frolf-backend/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── frolf-discord/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   ├── resume-postgres/
│   │   ├── kustomization.yaml
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   └── pvc.yaml
│   ├── frolf-postgres/
│   │   ├── kustomization.yaml
│   │   ├── statefulset.yaml
│   │   ├── service.yaml
│   │   └── pvc.yaml
│   └── frolf-nats/
│       ├── kustomization.yaml
│       ├── statefulset.yaml
│       └── service.yaml
│
├── infrastructure/                         # Platform services (Helm-based)
│   ├── argocd-app.yaml
│   ├── cert-manager-app.yaml
│   ├── sealed-secrets-app.yaml
│   └── oci-csi-driver-app.yaml
│
├── observability/                          # Monitoring (Helm-based)
│   ├── grafana-app.yaml
│   ├── prometheus-app.yaml
│   ├── loki-app.yaml
│   └── mimir-app.yaml
│
├── cluster-resources/                      # Raw YAML (simple resources)
│   ├── namespaces/
│   ├── storage/
│   └── network-policies/
│
├── sealed-secrets/                         # Sealed secret YAMLs
│
├── charts/                                 # Helm values
│   ├── argo-cd/values.yaml
│   ├── grafana/values.yaml
│   └── postgres/values.yaml (if using Helm for postgres)
│
├── ansible/
│   └── playbooks/
│       └── bootstrap-everything.yml        # ONE-COMMAND BOOTSTRAP
│
├── terraform/                              # Infrastructure as Code
│
└── scripts/
    ├── access-argocd.sh
    └── watch-sync.sh
```

---

## Key Principles

### 1. Use Kustomize for App Manifests (Organization)

- Each app has its own `kustomize/` directory
- Kustomize handles image management, common labels, config generation
- **No overlays** - just one configuration per app

### 2. Use Helm for Infrastructure (Complex Charts)

- ArgoCD, Grafana, Prometheus, Loki, Mimir use Helm
- These are complex and have well-maintained charts
- No need for Kustomize here

### 3. Use Raw YAML for Simple Resources

- Namespaces, PVs, storage classes are simple
- No need for Kustomize or Helm

---

## Critical refinements (do these to avoid future surprises)

A few practical gotchas to keep this plan robust in the long run:

- ConfigMapGenerator name-hashing trap

  - Kustomize's `configMapGenerator` appends a hash to generated ConfigMap names (eg. `app-config-abc123`). If your Deployment references the ConfigMap by name, that's fine as long as the Deployment is included in the same `kustomization.yaml` — Kustomize will rewrite the reference automatically. Do NOT hardcode the hashed name; keep your Deployment referencing the generator name and let kustomize handle replacement.

- Namespace ownership

  - Do NOT set `namespace:` inside `kustomization.yaml` files. Let the ArgoCD `Application.destination.namespace` control where resources are applied. This keeps Kustomize directories reusable (e.g., deploy the same kustomize to `resume-dev` by changing only the Application).

- SealedSecrets
  - Treat sealed secrets like any other resource: put the sealed YAML in the app `kustomize/<app>/` and include it in `resources:`. Do NOT use `secretGenerator` for SealedSecrets — it doesn't work with sealed YAMLs.

These three refinements are low-effort and will save hours debugging later.

---

## Example: Resume Backend with Kustomize

### Application Manifest

```yaml
# apps/resume-backend-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: resume-backend
  namespace: argocd
  annotations:
    argocd-image-updater.argoproj.io/image-list: backend=ocir.io/namespace/resume-backend
    argocd-image-updater.argoproj.io/backend.update-strategy: latest
spec:
  project: default
  source:
    repoURL: https://github.com/Black-And-White-Club/all-infrastructure
    targetRevision: main
    path: kustomize/resume-backend # Points to Kustomize directory
    kustomize:
      images:
        - name: resume-backend
          newTag: latest # ArgoCD Image Updater will update this
  destination:
    server: https://kubernetes.default.svc
    namespace: resume-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Kustomize Directory

```yaml
# kustomize/resume-backend/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: resume-app

resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml

commonLabels:
  app: resume-backend
  managed-by: argocd

images:
  - name: resume-backend
    newName: ocir.io/your-namespace/resume-backend
    newTag: latest # ArgoCD will override this
```

```yaml
# kustomize/resume-backend/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: resume-backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: resume-backend
  template:
    metadata:
      labels:
        app: resume-backend
    spec:
      containers:
        - name: backend
          image: resume-backend # Kustomize will replace this
          ports:
            - containerPort: 3000
          envFrom:
            - configMapRef:
                name: resume-backend-config
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: resume-postgres-credentials
                  key: connection-string
          resources:
            requests:
              memory: "256Mi"
              cpu: "200m"
            limits:
              memory: "512Mi"
              cpu: "500m"
```

```yaml
# kustomize/resume-backend/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: resume-backend
spec:
  selector:
    app: resume-backend
  ports:
    - port: 80
      targetPort: 3000
  type: ClusterIP
```

```yaml
# kustomize/resume-backend/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: resume-backend-config
data:
  NODE_ENV: production
  LOG_LEVEL: info
  PORT: "3000"
```

---

## Example: Shared Postgres Pattern (DRY)

Instead of duplicating Postgres configs, create reusable components:

### Resume Postgres

```yaml
# kustomize/resume-postgres/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: resume-db

resources:
  - statefulset.yaml
  - service.yaml
  - pvc.yaml

commonLabels:
  app: resume-postgres
  component: database

configMapGenerator:
  - name: postgres-config
    literals:
      - POSTGRES_DB=resume_db
      - POSTGRES_USER=resume_user
```

```yaml
# kustomize/resume-postgres/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: resume-postgres
  template:
    metadata:
      labels:
        app: resume-postgres
    spec:
      containers:
        - name: postgres
          image: postgres:15
          ports:
            - containerPort: 5432
          envFrom:
            - configMapRef:
                name: postgres-config
          env:
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: resume-postgres-credentials
                  key: password
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
              subPath: postgres
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: local-storage # or oci-block-storage
        resources:
          requests:
            storage: 8Gi
```

### Frolf Postgres (Similar but Different Config)

```yaml
# kustomize/frolf-postgres/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: frolf-bot

resources:
  - statefulset.yaml
  - service.yaml
  - pvc.yaml

commonLabels:
  app: frolf-postgres
  component: database

configMapGenerator:
  - name: postgres-config
    literals:
      - POSTGRES_DB=frolf_db
      - POSTGRES_USER=frolf_user
```

```yaml
# kustomize/frolf-postgres/statefulset.yaml
# Similar to resume-postgres/statefulset.yaml but:
# - Different labels (app: frolf-postgres)
# - Different secret name (frolf-postgres-credentials)
# - Larger storage (50Gi instead of 8Gi)
```

**Key point**: They share the same **structure** but different **values**. Kustomize keeps them DRY while allowing customization.

---

## Benefits of This Approach

### 1. Organization Without Complexity

- Each app has its own directory
- Clear structure: `kustomize/app-name/`
- No overlay confusion

### 2. DRY Principles

```yaml
# Instead of repeating in every deployment:
commonLabels:
  app: resume-backend
  managed-by: argocd
# Kustomize adds these to all resources automatically
```

### 3. Image Management

```yaml
# Kustomize handles image references
images:
  - name: resume-backend
    newName: ocir.io/namespace/resume-backend
    newTag: v1.2.3
# ArgoCD Image Updater updates this automatically
```

### 4. ConfigMap Generation

```yaml
# Generate ConfigMaps from literals
configMapGenerator:
  - name: app-config
    literals:
      - KEY=value
      - ANOTHER_KEY=another_value
# Kustomize creates unique names (app-config-abc123)
# Triggers rolling updates when config changes
```

### 5. Easy Testing

```bash
# Build and test locally
kustomize build kustomize/resume-backend

# Apply directly (for testing)
kustomize build kustomize/resume-backend | kubectl apply -f -

# Or let ArgoCD handle it (production)
```

---

## Migration from Raw Manifests

### Before (Raw Manifests)

```
manifests/
├── resume-backend/
│   ├── deployment.yaml      # Full YAML with hardcoded image
│   ├── service.yaml
│   └── configmap.yaml
└── frolf-backend/
    ├── deployment.yaml
    └── service.yaml
```

### After (Kustomize)

```
kustomize/
├── resume-backend/
│   ├── kustomization.yaml   # Image management, common labels
│   ├── deployment.yaml      # Cleaner, references image by name
│   ├── service.yaml
│   └── configmap.yaml
└── frolf-backend/
    ├── kustomization.yaml
    ├── deployment.yaml
    └── service.yaml
```

**What changed:**

- Added `kustomization.yaml` to each directory
- Deployments reference images by simple name
- Common labels/annotations defined once
- ConfigMaps can be generated from literals

**Migration steps:**

```bash
# 1. Move manifests
mv manifests/resume-backend kustomize/

# 2. Create kustomization.yaml
cd kustomize/resume-backend
cat > kustomization.yaml <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
  - service.yaml
  - configmap.yaml
commonLabels:
  app: resume-backend
images:
  - name: resume-backend
    newName: ocir.io/namespace/resume-backend
    newTag: latest
EOF

# 3. Update app manifest
# Change: path: manifests/resume-backend
# To: path: kustomize/resume-backend

# 4. Commit and sync
git add kustomize/ apps/
git commit -m "Migrate to Kustomize"
git push
```

---

## Complete Flow: One Command to Production

### Step 1: Run Bootstrap

```bash
export KUBECONFIG=$HOME/.kube/config-oci
ansible-playbook ansible/playbooks/bootstrap-everything.yml
```

### What Happens:

1. **Terraform** provisions OCI VMs (15 minutes)
2. **Ansible** waits for cluster to be ready
3. **Helm** installs ArgoCD (3 minutes)
4. **kubectl** applies Lich King (instant)
5. **Lich King** creates all ApplicationSets
6. **ApplicationSets** create all Applications
7. **Applications** deploy all resources using Kustomize

### Step 2: Watch It Sync

```bash
# Watch apps being created and synced
watch kubectl get applications -n argocd

# Watch pods coming up
watch kubectl get pods -A
```

### Step 3: Access ArgoCD

```bash
./scripts/access-argocd.sh
# Opens port-forward and shows credentials
```

### Total Time: ~20 minutes from zero to fully running

---

## Disaster Recovery (Rebuild from Scratch)

```bash
# 1. Delete everything in OCI
cd terraform
terraform destroy -auto-approve

# 2. Start over (literally one command)
cd ../ansible/playbooks
ansible-playbook bootstrap-everything.yml

# 3. Wait 20 minutes
# 4. Everything is back
```

---

## What Makes This "One Command"

### Everything is Declarative:

- **Terraform**: VMs, networking, storage
- **ArgoCD Apps**: What to deploy
- **Kustomize**: How to deploy it
- **Sealed Secrets**: Encrypted in Git

### No Manual Steps:

- ❌ No SSH into VMs
- ❌ No manual kubectl applies
- ❌ No copying files
- ❌ No running scripts on remote machines

### GitOps All the Way:

- Everything in Git
- ArgoCD watches Git
- Changes auto-deploy
- Rollback = git revert

### Self-Healing:

- ArgoCD auto-syncs
- ArgoCD self-heals
- Pods restart if they crash
- StatefulSets maintain replicas

---

## Summary: Kustomize Without Overlays

**Structure:**

```
kustomize/
├── app-1/
│   ├── kustomization.yaml
│   └── manifests
├── app-2/
│   ├── kustomization.yaml
│   └── manifests
└── app-3/
    ├── kustomization.yaml
    └── manifests
```

**Benefits:**

- ✅ Organization (one directory per app)
- ✅ DRY (common labels, image management)
- ✅ ConfigMap generation
- ✅ Works with ArgoCD Image Updater
- ✅ Easy to test locally
- ❌ No overlay complexity
- ❌ No environment management

**Use Cases:**

- ✅ Single production environment
- ✅ Self-hosted on one cluster
- ✅ Want clean structure
- ✅ Want DRY principles
- ✅ Want image tag management

**Perfect for your setup** - one cluster, one environment, maximum automation, zero complexity.
