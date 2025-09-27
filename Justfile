inventory:
    cd ansible && ansible-inventory --list

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
