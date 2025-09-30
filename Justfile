## Main tasks

socket := '/tmp/proxmox-ssh-tunnel.sock'
proxmox_domain := 'au-adelaide.tombarone.net'
proxmox_port := '8006'

deploy: inventory deploy_proxmox deploy_traefik deploy_test_webserver

destroy: inventory destroy_traefik destroy_test_webserver

# Open the proxmox management portal via an SSH tunnel
open_proxmox:
    ssh -fN -M -S {{ socket }} -L {{ proxmox_port }}:localhost:{{ proxmox_port }} root@{{ proxmox_domain }}
    python3 -m webbrowser https://localhost:{{ proxmox_port }}

# Close the proxmox SSH tunnel
close_proxmox:
    ssh -S {{ socket }} -O exit 0 root@{{ proxmox_domain }}

# Manage ansible secrets via SOPS
edit-secrets:
    sops edit inventory/au-adelaide/group_vars/all.sops.yaml

inventory:
    ansible-inventory --list

deploy_proxmox:
    ansible-playbook proxmox/deploy.yaml

deploy_traefik:
    ansible-playbook traefik/provision.yaml
    ansible-playbook traefik/setup.yaml

destroy_traefik:
    ansible-playbook traefik/destroy.yaml

deploy_test_webserver:
    ansible-playbook test_webserver/provision.yaml
    ansible-playbook test_webserver/setup.yaml

destroy_test_webserver:
    ansible-playbook test_webserver/destroy.yaml
