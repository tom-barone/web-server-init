## Main tasks

socket := '/tmp/proxmox-ssh-tunnel.sock'
proxmox_domain := 'au-adelaide.tombarone.net'
proxmox_port := '8006'

update: inventory deploy_proxmox deploy_traefik deploy_webserver

# Open the proxmox management portal via an SSH tunnel
open_proxmox:
    ssh -fN -M -S {{ socket }} -L {{ proxmox_port }}:localhost:{{ proxmox_port }} root@{{ proxmox_domain }}
    python3 -m webbrowser https://localhost:{{ proxmox_port }}

# Close the proxmox SSH tunnel
close_proxmox:
    ssh -S {{ socket }} -O exit 0 root@{{ proxmox_domain }}

# Manage ansible secrets via SOPS
edit-secrets:
    sops edit ansible/inventory/au-adelaide/group_vars/all.sops.yaml

inventory:
    cd ansible && ansible-inventory --list

deploy_proxmox:
    cd ansible && ansible-playbook proxmox/deploy.yaml

destroy_vm *FLAGS:
    cd ansible && ansible-playbook proxmox/99_delete_vm.yaml {{ FLAGS }}

deploy_traefik:
    cd ansible && ansible-playbook traefik/01_provision.yaml
    cd ansible && ansible-playbook traefik/02_setup.yaml

destroy_traefik:
    just destroy_vm -e vm_id=149

deploy_webserver:
    cd ansible && ansible-playbook test_webserver/01_provision.yaml
    cd ansible && ansible-playbook test_webserver/02_setup.yaml

destroy_test_webserver:
    just destroy_vm -e vm_id=150
