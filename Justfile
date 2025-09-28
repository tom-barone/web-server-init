inventory:
    cd ansible && ansible-inventory --list

setup_proxmox:
    cd ansible && ansible-playbook proxmox/01_update_packages.yaml
    cd ansible && ansible-playbook proxmox/02_harden_ssh.yaml
    cd ansible && ansible-playbook proxmox/03_enable_fail2ban_jail_for_sshd.yaml
    cd ansible && ansible-playbook proxmox/04_setup_postfix_relay.yaml
    cd ansible && ansible-playbook proxmox/05_create_debian_cloudinit_template.yaml

destroy_vm *FLAGS:
    cd ansible && ansible-playbook proxmox/99_delete_vm.yaml {{ FLAGS }}

create_traefik:
    cd ansible && ansible-playbook traefik/01_provision.yaml
    cd ansible && ansible-playbook traefik/02_setup.yaml

destroy_traefik:
    just destroy_vm -e vm_id=149

create_test_webserver:
    cd ansible && ansible-playbook test_webserver/01_provision.yaml
    cd ansible && ansible-playbook test_webserver/02_setup.yaml

destroy_test_webserver:
    just destroy_vm -e vm_id=150

edit_vars:
    sops edit ansible/inventory/au-adelaide/group_vars/all.sops.yaml
