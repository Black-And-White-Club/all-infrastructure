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
