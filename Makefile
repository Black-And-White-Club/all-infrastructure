.PHONY: help bootstrap terraform ansible install-argocd deploy-observability

help:
	@echo "Targets: terraform ansible install-argocd deploy-observability"

bootstrap: terraform ansible install-argocd deploy-observability
	@echo "Bootstrap outline: terraform -> ansible -> argocd -> observability"

terraform:
	@echo "Run terraform in ./terraform for the chosen environment (dev/stage/prod)."

ansible:
	@echo "Run ansible playbooks in ./ansible to configure cluster nodes and storage."

install-argocd:
	@echo "Install ArgoCD (we recommend installing via Helm and keeping values/overrides in ./charts/argo-cd)."

deploy-observability:
	@echo "Apply observability chart values (./observability/)."

COMPOSE=docker compose -f docker-compose.local.yml

.PHONY: help up infra pwa pwa-restart pwa-down logs down clean

help:
	@echo ""
	@echo "Local Development:"
	@echo "  make up           Start infra only (postgres, nats)"
	@echo "  make infra        Same as make up"
	@echo "  make pwa          Start infra + PWA dev"
	@echo "  make pwa-restart  Restart only the PWA container"
	@echo "  make pwa-down     Stop only the PWA container"
	@echo "  make logs         Tail logs for all services"
	@echo "  make down         Stop all services"
	@echo "  make clean        Stop services and remove volumes"
	@echo ""

# -----------------------------------------------------------------------------
# Infra only
# -----------------------------------------------------------------------------

up:
	$(COMPOSE) up -d postgres nats

infra: up

# -----------------------------------------------------------------------------
# Infra + PWA (DEV MODE)
# -----------------------------------------------------------------------------

pwa:
	$(COMPOSE) --profile with-pwa up -d

pwa-restart:
	$(COMPOSE) stop pwa
	$(COMPOSE) --profile with-pwa up pwa -d

pwa-down:
	$(COMPOSE) stop pwa

# -----------------------------------------------------------------------------
# Utilities
# -----------------------------------------------------------------------------

logs:
	$(COMPOSE) logs -f

down:
	$(COMPOSE) down

clean:
	$(COMPOSE) down -v --remove-orphans

# ====================================================================================
# Bastion / Kubeconfig Helpers
# ====================================================================================

# Start a port-forwarding session via OCI Bastion to the K8s API Server
# Requires OCI CLI and jq installed.
# Usage: make bastion-connect
.PHONY: bastion-connect
bastion-connect:
	@echo "Starting Bastion Session..."
	@scripts/bastion-connect.sh

# Update kubeconfig to point to local tunnel
.PHONY: kubeconfig-local
kubeconfig-local:
	@kubectl config set-cluster kubernetes --server=https://127.0.0.1:6443 --insecure-skip-tls-verify=true
	@kubectl config unset clusters.kubernetes.certificate-authority-data
	@kubectl config set-context kubernetes-admin@kubernetes --cluster=kubernetes --user=kubernetes-admin
	@kubectl config use-context kubernetes-admin@kubernetes
	@echo "Kubeconfig updated to localhost:6443 (insecure TLS)"
