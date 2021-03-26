# Overview

This is a group of playbooks and ansible tools/scripts to provision and manage Anthos Bare Metal on Intel NUCs

## Dependencies

> NOTE: Will figure out how to make this in code

```bash
pip install dnspython
```

```bash
ansible-galaxy collection install community.crypto
```

# Running

```bash
ansible-playbook abm_standalone.yml -i inventory.yml -K
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
# not 100% sure that the above installs the gce provisioner for molecule, so repeat just in case
pip install molecule-gce
```
```
