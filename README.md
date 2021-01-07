# Overview

This is a group of playbooks and ansible tools/scripts to provision and manage Anthos Bare Metal on Intel NUCs


# Running

```bash
ansible-playbook site.yml -i group_a.yml -K
```

# Development

Consider using Molecule to develop Roles

```bash
python -m pip install --user "molecule[andible,docker,lint]"
```