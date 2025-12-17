.PHONY: help bootstrap client sync-secrets deploy deploy-traefik deploy-vpn deploy-jellyfin clean

help:
	@echo "HomeLab Ansible Automation"
	@echo ""
	@echo "Usage:"
	@echo "  make bootstrap       Setup server (Consul, Vault, Nomad)"
	@echo "  make client          Setup this machine as Nomad client"
	@echo "  make sync-secrets    Sync secrets from Bitwarden to Nomad"
	@echo "  make deploy          Deploy all Nomad jobs"
	@echo "  make deploy-traefik  Deploy Traefik only"
	@echo "  make deploy-vpn      Deploy VPN stack only"
	@echo "  make deploy-jellyfin Deploy Jellyfin only"
	@echo "  make clean           Stop all services on server"

bootstrap:
	ansible-playbook bootstrap/site.yml --limit servers

client:
	ansible-playbook bootstrap/site.yml --limit clients --ask-become-pass

sync-secrets:
	ansible-playbook sync-secrets.yml

deploy:
	ansible-playbook deploy.yml

deploy-traefik:
	ansible-playbook deploy.yml -e '{"deploy_jobs": ["core/traefik.nomad.hcl"]}'

deploy-vpn:
	ansible-playbook deploy.yml -e '{"deploy_jobs": ["core/vpn.nomad.hcl"]}'

deploy-jellyfin:
	ansible-playbook deploy.yml -e '{"deploy_jobs": ["media/jellyfin.nomad.hcl"]}'

clean:
	ssh homelab 'sudo systemctl stop nomad vault consul || true'
