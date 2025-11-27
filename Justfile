default: help

# Provision and deploy everything
deploy:
    @just run-playbook ./playbooks/proxmox/deploy.yaml
    @just run-playbook ./playbooks/traefik/deploy.yaml
    @just run-playbook ./playbooks/pi_vpn/deploy.yaml
    @just run-playbook ./playbooks/dokku_sandbox/deploy.yaml
    @just run-playbook ./playbooks/jqc_staging/deploy.yaml

# Destroy everything
destroy:
    @read -p "Are you sure you want to destroy everything? Press Ctrl+C to cancel or Enter to continue..." _
    @just run-playbook ./playbooks/dokku_sandbox/destroy.yaml
    @just run-playbook ./playbooks/traefik/destroy.yaml

# Open all management dashboards
open-dashboards:
    python3 -m webbrowser https://$(just get proxmox.ip_address):8006 # Proxmox
    python3 -m webbrowser http://$(just get vms.traefik.ip_address):8080/dashboard/ # Traefik
    python3 -m webbrowser $(just get router.settings_url) # Router Settings

# Edit the SOPS encrypted inventory file
edit-inventory:
    sops edit inventory.sops.yaml

help:
    @just --list

ssh-proxmox:
    ssh root@$(just get proxmox.ip_address)

ssh-traefik:
    ssh $(just get vms.traefik.ip_address)

ssh-dokku-sandbox:
    ssh $(just get vms.dokku_sandbox.ip_address)

ssh-vpn:
    ssh $(just get vms.pi_vpn.ip_address)

# ------ Secondary Recipes ------

[private]
get KEY:
    sops exec-file inventory.sops.yaml 'yq ".all.vars.{{ KEY }}" {}'

# Run a playbook with the decrypted inventory
[private]
run-playbook *COMMAND:
    sops exec-file inventory.sops.yaml 'ansible-playbook -i {} {{ COMMAND }}'
