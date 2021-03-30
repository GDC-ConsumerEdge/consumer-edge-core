# Overview

This is a group of playbooks and ansible tools/scripts to provision and manage Anthos Bare Metal on Intel NUCs

## Dependencies

> NOTE: Will figure out how to make this in code

```bash
pip install dnspython
```

# Running

```bash
ansible-playbook abm_standalone.yml -i inventory.yml -K
```

# Update/Upgrade OS

```bash
ansible-playbook -K -i <INVENTORY>.yml <PLAYBOOK>.yml

# example
ansible-playbook -K -i group_a.yml abm_standalone.yml
```

## Using Molecule

If you wish to use Molecule to develop the roles, install the following:

```bash
python -m pip install --user "molecule[ansible,docker,lint,gce]"
# not 100% sure that the above installs the gce provisioner for molecule, so repeat just in case
pip install molecule-gce
```
