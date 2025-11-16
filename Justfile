default: help

# Provision and deploy everything
deploy:
    @just run-playbook ./playbooks/proxmox/deploy.yaml
    @just run-playbook ./playbooks/traefik/deploy.yaml
    @just run-playbook ./playbooks/pi_vpn/deploy.yaml
    @just run-playbook ./playbooks/dokku_sandbox/deploy.yaml

# Destroy everything
destroy:
    @read -p "Are you sure you want to destroy everything? Press Ctrl+C to cancel or Enter to continue..." _
    @just run-playbook ./playbooks/dokku_sandbox/destroy.yaml
    @just run-playbook ./playbooks/traefik/destroy.yaml

# Open all management dashboards
open-dashboards:
    python3 -m webbrowser https://$(just proxmox_ip):8006 # Proxmox
    python3 -m webbrowser http://$(just traefik_ip):8080/dashboard/ # Traefik
    python3 -m webbrowser $(just router_settings_url) # Router Settings

# Edit the SOPS encrypted inventory file
edit-inventory:
    sops edit inventory.sops.yaml

help:
    @just --list

ssh-traefik:
    ssh $(just traefik_ip)

ssh-proxmox:
    ssh root@$(just proxmox_ip)

# ------ Secondary Recipes ------

# Extract the proxmox IP address from the encrypted inventory
[private]
proxmox_ip:
    sops exec-file inventory.sops.yaml 'yq ".all.vars.proxmox.ip_address" {}'

# Extract the traefik IP address from the encrypted inventory
[private]
traefik_ip:
    sops exec-file inventory.sops.yaml 'yq ".all.vars.vms.traefik.ip_address" {}'

[private]
router_settings_url:
    sops exec-file inventory.sops.yaml 'yq ".all.vars.router.settings_url" {}'

# Run a playbook with the decrypted inventory
[private]
run-playbook *COMMAND:
    sops exec-file inventory.sops.yaml 'ansible-playbook -i {} {{ COMMAND }}'
