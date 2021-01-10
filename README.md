# Overview

This is a group of playbooks and ansible tools/scripts to provision and manage Anthos Bare Metal on Intel NUCs


# Running

```bash
ansible-playbook site.yml -i group_a.yml -K
```

# Update/Upgrade OS

```bash
ansible-playbook <PLAYBOOK>.yml --tags "maintenance" -i <INVENTORY>.yml -K

# example
ansible-playbook abm_standalone_kvm.yml --tags "maintenance" -i group_a.yml -K
```

# Development

Consider using Molecule to develop Roles

```bash
python -m pip install --user "molecule[andible,docker,lint,gce]"
```