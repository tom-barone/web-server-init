## Main tasks

proxmox_socket := '/tmp/proxmox-ssh-tunnel.sock'
traefik_socket := '/tmp/traefik-ssh-tunnel.sock'
proxmox_domain := 'au-adelaide.tombarone.net'

default: help

# Open all management dashboards
open-dashboards: open_proxmox_dashboard open_traefik_dashboard

# Close all management dashboards
close-dashboards: close_proxmox_dashboard close_traefik_dashboard

# Deploy all infrastructure components
deploy: deploy_proxmox deploy_traefik

# Manage ansible secrets via SOPS
edit-secrets:
    sops edit inventory/au-adelaide/group_vars/all.sops.yaml

# Deploy proxmox
deploy_proxmox:
    ansible-playbook ./playbooks/proxmox/deploy.yaml
    ansible-playbook ./playbooks/proxmox/create_debian_cloudinit_template.yaml

# Open the proxmox dashboard via an SSH tunnel
open_proxmox_dashboard: close_proxmox_dashboard
    ssh -fN -M -S {{ proxmox_socket }} -L 8006:localhost:8006 root@{{ proxmox_domain }}
    python3 -m webbrowser https://localhost:8006

# Close the proxmox SSH tunnel
close_proxmox_dashboard:
    ssh -S {{ proxmox_socket }} -O exit root@{{ proxmox_domain }} || true
    rm -f {{ proxmox_socket }}

# Deploy the traefik reverse proxy VM
deploy_traefik:
    ansible-playbook ./playbooks/traefik/deploy.yaml

# Destroy the traefik reverse proxy VM
destroy_traefik:
    ansible-playbook ./playbooks/traefik/destroy.yaml

# Open the Traefik dashboard via an SSH tunnel
open_traefik_dashboard: close_traefik_dashboard
    ssh -fN -M -S {{ traefik_socket }} -L 8080:localhost:8080 -p 9049 cloudinit@{{ proxmox_domain }}
    python3 -m webbrowser http://localhost:8080/dashboard/

# Close the traefik SSH tunnel
close_traefik_dashboard:
    ssh -S {{ traefik_socket }} -O exit cloudinit@{{ proxmox_domain }} || true
    rm -f {{ traefik_socket }}

# Deploy all configured VMs
deploy_vms:
    ansible-playbook ./playbooks/vms/deploy.yaml

# Destroy all configured VMs (asks for confirmation)
destroy_vms:
    ansible-playbook ./playbooks/vms/destroy.yaml

help:
    @just --list
