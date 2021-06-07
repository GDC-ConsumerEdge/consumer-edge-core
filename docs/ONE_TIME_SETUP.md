# One-time setup

Each of these segments are required to setup both the **Provisioning machine** and the **Target machine(s)**.

---

TOC: [Provision Target Machines](#provision-target-machines) | [ Access Target Machines ](#access-target-machines)

---

## Establishing a Baseline

[Target machines](../README.md#terms-to-know) are the physical or cloud machines that will be running the solution. The one-time installation process is necessary to establish a baseline that is common between both the Cloud and Physical machines. This baseline is then used by Ansible playbooks to provision a target machine.

These steps will need to be followed for the first installation, or any subsquent refreshing of the installation (ie, wiping and starting from scratch)

In this "one-time-setup", you will perform four primary goals:

1. Setup a bootable USB stick<sup>†</sup> containing Ubuntu 20.04 LTS
1. Setup SSH keys to allow passwordless access to the remote machine
1. Setup the **provisioning** machine with Ansible and Ansible dependencies
1. Setup inventory files

<sup>†</sup> PXE is out of scope, but follows similar concept.

## Goal 1 - Setup OS on Physical target machine(s)

> NOTE: Each of these steps are performed for each target machine.

> NOTE: This step is required for Physical targets and is not (cannot) be applied to Cloud targets

1. Create a bootable USB stick with Ubuntu 20.04 LTS
    * USB Boot Stick (Ubuntu option) -- https://ubuntu.com/tutorials/create-a-usb-stick-on-ubuntu#1-overview
    * USB Boot Stick (Windows option) -- https://ubuntu.com/tutorials/create-a-usb-stick-on-windows#1-overview
    * USB Boot Stick (MacOS option) -- https://ubuntu.com/tutorials/create-a-usb-stick-on-macos#1-overview

    > NOTE: 20.10 will NOT work, only 18.04 LTS or 20.04 LTS is supported

1. Insert USB and install Ubuntu 20.04 LTS

    > NOTE: USB may need to adjust UEFI/BIOS to boot from USB drive. Depending on BIOS/UEFI, this is found in the "boot" menu. For some BIOS, `F7` pressed during initial boot provides a quick `boot option` without editing the entire BIOS

    1. During setup, select a hostname using some convention. In this repo, `nuc-x` is the convention. For example, Store 1's NUC would be hostname `nuc-1`, Store 2 would be `nuc-2`, etc.
    1. (Optional, but recommended) If your router can reserve hostname->IP, reserve an IP but let Ubuntu use DHCP to acquire IP addresses
    1. Create a new `user` and set a password (both will be used to access the target box). It's best to keep the same username and password for all *target machines* for automation purposes.
        > Remember this `user` and `password`
    1. Install "OpenSSH" and no other software during initial setup
    1. Double check, you only set "hostname", created a user (use the same username and password for all machines) and you added OpenSSH
    1. Reboot as prompted.
    1. Login with the *username* and *password* created durin the setup. If any errors, restart process

1. At the completion of this provisioning, you should be able to SSH into each of the target machine(s) using the same `username` and `password` established in the setup using the hostname convention `nuc-x`. Some domains/routers will automatically postfix `.lan` or `.localdomain`, so try these options if `nuc-x` does not resolve.
    * Example
        ```bash
        # Prompted for password
        ssh myusername@nuc-1
        ```

## Goal 2 - Establishing Passwordless SSH

> NOTE: Some steps are required for both target types unless indicated.

The following are performed from the **provisioning machine**.

1. Ping each machine (note, if failures, try once again before getting nervous). Also, see note below about `.lan` or `.localdomain` suffix that some routers automatically append for hostname resolution. NOTE: `nuc` or `cnuc` may need to be adjusted based on Physical (`nuc`) or Cloud (`cnuc`)
    ```bash
    # Set however many machines you have provisioned. This example is 5
    export MACHINE_COUNT=5
    for i in `seq $MACHINE_COUNT`; do
        HOSTNAME="nuc-$i.lan" # chose 'cnuc' or 'nuc' according to your scenario
        ping -c 3 ${HOSTNAME}
    done
    ```
    > Check that your router provides `<hostname>.lan` or `<hostname>.localdomain` naming, if not, adjust to match

    > NOTE: If this fails, you might want to add each hostname to your /etc/hosts file matching the `IP` of the target machine. There are many documents on the internet and furhter description is beyond the scope of this document.

1. Create (or use) SSH key on provisioning box (your laptop, another machine, etc).
    ```bash
    # Physical targets
    ssh-keygen -t ed25519 -f ~/.ssh/nucs
    ```
    ```bash
    # Cloud targets
    ssh-keygen -t ed25519 -f ~/.ssh/cnucs-cloud
    ```
    > :warning: **DO NOT** use a passphrase

1. Setup SSH for passwordless access using SSH Configuration
    * Create or add to ~/.ssh/config
    * Replace `<user>` with the username created in step 1
        * > NOTE: If working with cloud instances, see second SSH config file example
    * Repeat block as needed to match the target machine count.

    #### Physical SSH Config
    ```yaml
    Host nuc-1.lan
    HostName nuc-1.lan
    User <user>
    IdentityFile ~/.ssh/nucs

    Host nuc-2.lan
    HostName nuc-2.lan
    User <user>
    IdentityFile ~/.ssh/nucs

    Host nuc-3.lan
    HostName nuc-3.lan
    User <user>
    IdentityFile ~/.ssh/nucs

    Host nuc-4.lan
    HostName nuc-4.lan
    User <user>
    IdentityFile ~/.ssh/nucs

    Host nuc-5.lan
    HostName nuc-5.lan
    User <user>
    IdentityFile ~/.ssh/nucs
    ```

    #### Cloud SSH Config (optional)

    > NOTE: The cloud and physical SSH Configs need to co-exist in same file IF you're using both options. Cloud is not required and it is recommended to use `gcloud compute ssh abm-admin@<IP of machine>` due to ephemeral nature of Cloud machines.

    ```yaml
    # NOTE: hostname resolution is required (ie, use /etc/hosts with IP address corresponding to `cnuc-x`)
    Host cnuc-1.lan
    HostName cnuc-1.lan
    User abm-admin
    IdentityFile ~/.ssh/cnucs-cloud
    ```

    > NOTE: The SSH key MUST be permissions `600` (rw owner only) and the config must be minimally `644` (rw owner, read other), but `600` is ok too

1. OPTIONAL - Some routers and/or systems may not have `.lan` suffix name resolution. Entries can be made to the `/etc/hosts` file (linux only) for DNS resolution for `nuc-x.lan`. Below is an example where the resolution is to the Router's gateway (may not be your destination depending on local router)

    ```yaml
    # Example /etc/hosts file where each
    192.168.2.2     nuc-1.lan
    192.168.2.3     nuc-2.lan
    192.168.2.4     nuc-3.lan
    192.168.2.5     nuc-4.lan
    192.168.2.6     nuc-5.lan
    ```

1. Copy SSH keys to all target machines
    ```
    ssh-copy-id ${user}@nuc-x.lan
    ```
    * Use the password and user created in step 1.
    * Repeat for all machines
1. Done! If you can SSH into all target machines without using a password or referencing an identity file, then you're ready to setup Ansible.

## Goal 3 - Setup Ansible on the Provisioning machine

1. Provisioning machine needs to have Python 3.x (3.7+ is recommended)

    1. Test python version:

        ```bash
        python --version
        ```

1. Sometimes systems have `python` and `python3`. Reference https://docs.ansible.com/ansible/latest/reference_appendices/python_3_support.html for reference on how to support `python3` (often adding `ansible_python_interpreter=/usr/bin/python3` to the Ansible config is required, along with all depenedencies installed with `pip3`)

### Fast "install all depencencies"
1. Run this if you don't care about precise used/unused libraries
    ```bash
    pip install --upgrade pip # upgrade pip just-in-case
    pip install ansible
    pip install dnspython
    pip install requests
    pip install google-auth
    ```

## Goal 4 - Setting up Inventory files

Inventory files contain information about how to connect to target machines and variables specific to the type of inventory. There are two types of files that correspond to `physical` and `cloud`. One inventory file is required for each type, so if you want to use both physical and cloud, you will have 2 inventory files.

### Cloud inventory file

Inventory for GCP is dynamic, meaning the GCP module will query the project + region for cloud resources to use as inventory. As far as Ansible is concerned, GCP inventory is dynamic so the example inventory has placeholders that are replaced using `envsubst` (NOTE: `envsubst` may need to be added to the **provisioning machine**). When running playbooks, Ansible will use the pre-provisioned GCE instances. The inventory file does NOT build new GCE machines.

1. Setup Environment Variables

    Review the [required environment variables](../README.me#required-environment-variables) on the primary README documentation. Establish the required variables and proceed.

1. Create a service account key and set an environment varaible (`LOCAL_GSA_FILE`) to that location

    1. A helper script is provided to generate, provision with IAM roles and download the key

        ```bash
        # Follow prompts
        ./scripts/create-primary-gsa.sh

        export LOCAL_GSA_FILE="./remote-gsa-key.json"
        ```

    > NOTE: Add the `export LOCAL_GSA_FILE=...` line to `.bashrc` or `.envrc` (if using `direnv`) so new shells can establish this required environment variable

1. Establish GCP Inventory File "inventory/gcp.yaml"

    ```bash
    # note "gcp.yaml", this name convention is required for the gcp module plugin
    envsubst < inventory-cloud-example.yaml > inventory/gcp.yaml
    ```

> NOTE: If the `envsubst` dependency is missing, install using `apt-get install gettext-base`

### Physical Inventory file

In order to create an inventory file, use the example file `inventory-physical-example.yml` and place the contents in `inventory/inventory.yaml`

```bash
# Example using envsubst (not required unless the example file has environment variables)
envsubst < inventory-physical-example.yaml > inventory/inventory.yaml
```

> NOTE: Check the contents and make sure the quantity of hostnames is correct for your situation

### Validating Inventory Files

1. Test inventory integration

    1. Run the `scripts/health-check.sh` script to test inventory.

    1. If any errors, see below section on "Troubleshooting Inventory"

#### Troubleshooting Inventory

* **IF** using WSL2 on Windows and Ubuntu, a known bug within WSL and clock synchronization exists (https://www.reddit.com/r/bashonubuntuonwindows/comments/ihq7ar/clock_for_wsl_is_different_than_windows_how_to/).  This will manifest as an error `invalid_grant` on the JWT token, despite a fresh GSA key.

    ```bash
    # Sync HW Clock (this will not work with chromebook/crostini)
    sudo hwclock -s
    ```

* Try SSH to the failed connections

    ```bash
    ssh -i ~/.ssh/nuc <username>@<hostname>
    ## IF not successful, verify SSH key has been established and copied to target machine(s)

    ssh <username>
    ## If not successful, check the SSH Config for proper HOST, HOSTNAME, and USER configuration
    ```

## Ready to provision

After completing all of these steps, you are ready to proceed with provisioning.