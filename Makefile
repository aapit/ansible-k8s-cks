.PHONY: help deps up inventory ping site reset down all

help:
	@echo "CKS practice cluster - Ansible"
	@echo ""
	@echo "  make deps       Install required Ansible collections"
	@echo "  make up         Launch fresh Multipass VMs (cp1, worker1)"
	@echo "  make inventory  Regenerate inventory/hosts.yml from running VMs"
	@echo "  make ping       Ansible connectivity check"
	@echo "  make site       Provision everything (kubeadm + CNI + add-ons + tooling)"
	@echo "  make all        up + inventory + site"
	@echo "  make reset      kubeadm reset on all nodes (keeps VMs)"
	@echo "  make down       Delete the VMs"

deps:
	ansible-galaxy collection install -r requirements.yml

up:
	./scripts/multipass-up.sh

inventory:
	./scripts/gen-inventory.sh

ping:
	ansible all -m ping

site:
	ansible-playbook playbooks/site.yml

all: up
	sleep 20
	$(MAKE) inventory
	$(MAKE) site

reset:
	ansible-playbook playbooks/reset.yml

down:
	./scripts/multipass-down.sh
