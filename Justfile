inventory:
    ansible-inventory -i ansible/inventory.yaml --list

create_traefik:
    ansible-playbook ./ansible/traefik/01_create_vm.yaml -i ansible/inventory.yaml --user root
