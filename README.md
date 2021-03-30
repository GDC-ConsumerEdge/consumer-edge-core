# Overview

This is a group of playbooks and ansible tools/scripts to provision and manage Anthos Bare Metal on Intel NUCs

# From Scratch

### Terms

Target machine(s) - The machine that the cluster is being installed into/onto (ie, NUC, GCE, etc)
Provisioning box - The machine that initiates the `ansible` run. Typically a laptop or cloud-console if GCE (must be able to reach target machines)

1. Use whatever method desired to put Ubuntu 20.04 LTS on the machine (NOTE: 20.10 will NOT work)
    1. Setup a hostname with some convention. In this repo, `store-x` is used (ie. `store-1`, `store-2`...)
    1. Optional, if your router can reserve hostname->IP, reserve an IP but let Ubuntu use DHCP
    1. Create a user, set a password (both will be used below). It's best to keep the same username and password for automation
    1. Add "OpenSSH" and no other software
    1. Double check, you only set "hostname", created a user (use the same username and password for all machines) and you added OpenSSH
1. Ping each machine (note, if failures, try once again before getting nervous)
    ```bash
    export MACHINE_COUNT=5
    for i in `seq $MACHINE_COUNT`; do
        ping -c 3 store-$i.lan
    done
    ```
    > NOTE: If this fails, you might want to add each hostname to your /etc/hosts file. This is beyond the scope of this workshop
1. Create (or use) SSH key on provisioning box (your laptop, another machine, etc).
    ```bash
    ssh-keygen -t ed25519 -f ~/.ssh/nucs
    ```
    * DO not use a passphrase
1. Setup SSH for password less access
    * Create or add to ~/.ssh/config
    * Replace <user> with the username created in step 1
    ```yaml
    Host store-1.lan
    HostName store-1.lan
    User <user>
    IdentityFile ~/.ssh/nucs

    Host store-2.lan
    HostName store-2.lan
    User <user>
    IdentityFile ~/.ssh/nucs

    Host store-3.lan
    HostName store-3.lan
    User <user>
    IdentityFile ~/.ssh/nucs

    Host store-4.lan
    HostName store-4.lan
    User <user>
    IdentityFile ~/.ssh/nucs

    Host store-5.lan
    HostName store-5.lan
    User <user>
    IdentityFile ~/.ssh/nucs
    ```

    > NOTE: The SSH key MUST be permissions `600` (rw owner only) and the config must be minimally `644` (rw owner, read other), but `600` is ok too

1. Copy SSH keys to all target machines
    ```
    ssh-copy-id ${user}@store-x.lan
    ```
    * Use the password and user created in step 1.
    * Repeat for all machines
1. Done! If you can SSH into all target machines without using a password or referencing an identity file, then you're ready to setup Ansible.


# Ansible Setup

Download Ansible 2.10+ (easiest is to use `pip`). This tutorial/workshop assumes you have Python 3.7+ on the command-line and `pip --version` returns a non-error

```bash
# Install Ansible
pip install ansible
# dnspython is used by ansible for 'dig' lookup in the inventory file
pip install dnspython
```

## Installing Anthos Bare Metal

The Ansible script installs Ansible Bare Metal on all of the inventory hosts.

You will need to define 3 Environment Variables, as well as making any environment-specific change (like IP ranges)

### Required Environment Variables

| Environment Variable | Required | Description | Default Value |
|:---------------------|:--------:|:------------|:-------------:|
| LOCAL_GSA_FILE       |  Y       |  Google Service Account key to a GSA that is used to provision and activate all Google-based services (all `gcloud` commands) | N/A |
| PROJECT_ID           |  Y       |  Google Project ID to put clusters, Service Accounts and API services into | N/A |
| REGION               |  N       |  Google default region | us-central1 |
| ZONE                 |  N       |  Google default zone | us-central1-a |

### Environment IPs

* control_plane_vip -- IP address that is addressable & available, not overlapping with other clusters, but not pre-allocated. This is created during the process
* ingress_vip -- Must be in the Load Balancer pool for the cluster, same rules as control_plane_vip for availability
* load_balancer_pool_cidr -- IP addresses for the LoadBalancers (bundled mode) can attach to, same rules as control_plane_vip
* control_plane_ip -- different than the `control_plane_vip`, this is the IP of the box you are installing on

> NOTE: The default inventory file sets up 9 LBs allocated per cluster, with 1 taken for Ingress (sufficient for POC and basic work)

### Running Ansible Install

> NOTE: Be sure to copy/clone the `inventory.yml` file and verify variables are acceptable for YOUR environment. Watch out for Docker and KIND IP overlaps if changing the service or pod CIDR blocks

```bash
ansible-playbook -K -i inventory.yml abm_standalone.yml
```

## Update/Upgrade OS

Equivalent of `apt-get update && apt-get upgrade` and `gcloud components update` (both without requiring human input)

```bash
# Update all servers ()
ansible-playbook -K -i group_a.yml update-servers.yml
```

## Using Molecule

If you wish to use Molecule to develop the roles, install the following:

```bash
python -m pip install --user "molecule[ansible,docker,lint,gce]"
# not 100% sure that the above installs the gce provisioner for molecule, so repeat just in case
pip install molecule-gce
```
