default: help

# Provision and deploy everything
deploy:
    ansible-playbook ./playbooks/proxmox/deploy.yaml
    ansible-playbook ./playbooks/traefik/provision.yaml
    ansible-playbook ./playbooks/traefik/deploy.yaml
    ansible-playbook ./playbooks/vms/provision.yaml
    ansible-playbook ./playbooks/dokku_sandbox/deploy.yaml

# Destroy everything
destroy:
    @read -p "Are you sure you want to destroy all VMs? Press Ctrl+C to cancel or Enter to continue..." _
    ansible-playbook ./playbooks/vms/destroy.yaml
    ansible-playbook ./playbooks/traefik/destroy.yaml

proxmox_socket := '/tmp/proxmox-ssh-tunnel.sock'
traefik_socket := '/tmp/traefik-ssh-tunnel.sock'
proxmox_domain := 'au-adelaide.tombarone.net'

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

help:
    @just --list
