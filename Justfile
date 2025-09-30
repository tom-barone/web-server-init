## Main tasks

proxmox_socket := '/tmp/proxmox-ssh-tunnel.sock'
traefik_socket := '/tmp/traefik-ssh-tunnel.sock'
proxmox_domain := 'au-adelaide.tombarone.net'

default: help

# Open all management dashboards
open-dashboards:
    ssh -fN -M -S {{ proxmox_socket }} -L 8006:localhost:8006 root@{{ proxmox_domain }}
    python3 -m webbrowser https://localhost:8006 # Proxmox
    ssh -fN -M -S {{ traefik_socket }} -L 8080:localhost:8080 -p 9049 cloudinit@{{ proxmox_domain }}
    python3 -m webbrowser http://localhost:8080/dashboard/ # Traefik

# Close all management dashboards
close-dashboards:
    ssh -S {{ proxmox_socket }} -O exit root@{{ proxmox_domain }} || true
    ssh -S {{ traefik_socket }} -O exit cloudinit@{{ proxmox_domain }} || true
    rm -f {{ proxmox_socket }} {{ traefik_socket }}

# Provision and deploy all infrastructure components
deploy:
    ansible-playbook ./playbooks/proxmox/deploy.yaml
    ansible-playbook ./playbooks/traefik/provision.yaml
    ansible-playbook ./playbooks/traefik/deploy.yaml
    ansible-playbook ./playbooks/vms/provision.yaml
    ansible-playbook ./playbooks/dokku_sandbox/deploy.yaml

# Destroy the traefik reverse proxy VM
destroy_traefik:
    ansible-playbook ./playbooks/traefik/destroy.yaml

# Destroy all configured VMs (asks for confirmation)
destroy_vms:
    ansible-playbook ./playbooks/vms/destroy.yaml

help:
    @just --list
