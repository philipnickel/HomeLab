.PHONY: help backup deploy deploy-infra deploy-jobs terraform-init terraform-plan terraform-apply ansible-check ansible-infra ansible-jobs clean status

help:
	@echo "HomeLab Infrastructure as Code"
	@echo ""
	@echo "Quick Start:"
	@echo "  make deploy           Full deployment (Terraform + Ansible)"
	@echo "  make deploy-infra     Deploy infrastructure only (no jobs)"
	@echo "  make deploy-jobs      Deploy Nomad jobs only"
	@echo ""
	@echo "Terraform Commands:"
	@echo "  make terraform-init   Initialize Terraform"
	@echo "  make terraform-plan   Preview infrastructure changes"
	@echo "  make terraform-apply  Apply infrastructure changes"
	@echo ""
	@echo "Ansible Commands:"
	@echo "  make ansible-check    Dry-run Ansible playbook"
	@echo "  make ansible-infra    Configure VMs (no jobs)"
	@echo "  make ansible-jobs     Deploy Nomad jobs"
	@echo ""
	@echo "Utilities:"
	@echo "  make backup           Backup configs to local machine"
	@echo "  make status           Show cluster status"
	@echo "  make clean            Stop all services"

# ============================================
# Full Deployment
# ============================================
deploy: terraform-apply ansible-infra ansible-jobs
	@echo "Deployment complete!"

deploy-infra: terraform-apply ansible-infra
	@echo "Infrastructure deployed!"

deploy-jobs: ansible-jobs
	@echo "Jobs deployed!"

# ============================================
# Terraform
# ============================================
terraform-init:
	cd terraform/proxmox && terraform init

terraform-plan:
	cd terraform/proxmox && terraform plan

terraform-apply:
	cd terraform/proxmox && terraform apply -auto-approve

# ============================================
# Ansible
# ============================================
ansible-check:
	cd ansible && ansible-playbook site.yml --check

ansible-infra:
	cd ansible && ansible-playbook site.yml --tags infrastructure

ansible-jobs:
	cd ansible && ansible-playbook site.yml --tags nomad-jobs

# ============================================
# Utilities
# ============================================
backup:
	./scripts/backup.sh

status:
	@echo "=== Nomad Status ==="
	@ssh root@192.168.0.200 "nomad status" 2>/dev/null || echo "Cannot connect to Nomad server"
	@echo ""
	@echo "=== Consul Services ==="
	@ssh root@192.168.0.200 "consul catalog services" 2>/dev/null || echo "Cannot connect to Consul"

clean:
	@echo "Stopping all Nomad jobs..."
	@ssh root@192.168.0.200 "nomad job status -short | tail -n +2 | awk '{print \$$1}' | xargs -I {} nomad job stop {}" 2>/dev/null || true
	@echo "Done."
