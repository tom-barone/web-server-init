default: help

# Provision and deploy everything
deploy:
    #@just run-playbook ./playbooks/proxmox/deploy.yaml
    @just run-playbook ./playbooks/traefik/provision.yaml
    @just run-playbook ./playbooks/traefik/deploy.yaml

    #ansible-playbook ./playbooks/traefik/provision.yaml
    #ansible-playbook ./playbooks/traefik/deploy.yaml
    #ansible-playbook ./playbooks/vms/provision.yaml
    #ansible-playbook ./playbooks/dokku_sandbox/deploy.yaml

# Destroy everything
destroy:
    @read -p "Are you sure you want to destroy everything? Press Ctrl+C to cancel or Enter to continue..." _
    @just run-playbook ./playbooks/proxmox/destroy_vms.yaml
    #@just run-playbook ./playbooks/proxmox/destroy_vm_templates.yaml

# Open all management dashboards
open-dashboards:
    ssh -fN -M -S /tmp/proxmox-ssh-tunnel.sock -L 8006:localhost:8006 root@$(just proxmox_ip)
    python3 -m webbrowser https://localhost:8006 # Proxmox
    ssh -fN -M -S /tmp/traefik-ssh-tunnel.sock -L 8080:localhost:8080 cloudinit@$(just traefik_ip)
    python3 -m webbrowser http://localhost:8080/dashboard/ # Traefik

# Close all management dashboards
close-dashboards:
    ssh -S /tmp/proxmox-ssh-tunnel.sock -O exit root@$(just proxmox_ip) || true
    ssh -S /tmp/traefik-ssh-tunnel.sock -O exit cloudinit@$(just traefik_ip) || true
    rm -f /tmp/proxmox-ssh-tunnel.sock /tmp/traefik-ssh-tunnel.sock

# Edit the SOPS encrypted inventory file
edit-inventory:
    sops edit inventory.sops.yaml

help:
    @just --list

# ------ Secondary Recipes ------

# Extract the proxmox IP address from the encrypted inventory
[private]
proxmox_ip:
    sops exec-file inventory.sops.yaml 'yq ".all.vars.proxmox.ip_address" {}'

# Extract the traefik IP address from the encrypted inventory
[private]
traefik_ip:
    sops exec-file inventory.sops.yaml 'yq ".all.vars.vms.traefik.ip_address" {}'

# Run a playbook with the decrypted inventory
[private]
run-playbook *COMMAND:
    sops exec-file inventory.sops.yaml 'ansible-playbook -i {} {{ COMMAND }}'
