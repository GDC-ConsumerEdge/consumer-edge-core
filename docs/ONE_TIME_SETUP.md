# One-time setup

Each of these segments are required to setup both the **Provisioning machine** and the **Target machine(s)**.

---

TOC: [Provision Target Machines](#provision-target-machines) | [ Access Target Machines ](#access-target-machines)

---

## Provision Target Machines

#### GOAL: Install operating System, provision & install OpenSSH on Target Machine(s)

> NOTE: Each of these steps are performed for each target machine

1. Use whatever method desired to put Ubuntu 20.04 LTS on the machine (NOTE: 20.10 will NOT work). PXE or Bootable USB are most common methods.
1. Start setup for Ubuntu (USB may need to adjust UEFI/BIOS to boot from USB drive)
    1. During setup, select a hostname using some convention. In this repo, `nuc-x` is the convention. For example, Store 1's NUC would be hostname `nuc-1`, Store 2 would be `nuc-2`, etc.
    1. (Optional, but recommende) If your router can reserve hostname->IP, reserve an IP but let Ubuntu use DHCP to acquire IP addresses
    1. Create a new `user` and set a password (both will be used to access the target box). It's best to keep the same username and password for all *target machines* for automation purposes.
        > Remember this `user` and `password`
    1. Install "OpenSSH" and no other software during initial setup
    1. Double check, you only set "hostname", created a user (use the same username and password for all machines) and you added OpenSSH
    1. Reboot as prompted.
    1. Login with the *username* and *password* created durin the setup. If any errors, restart process

## Access Target Machines

### Goal: Create passwordless access to target machines

The following are performed from the **provisioning machine**.

1. Ping each machine (note, if failures, try once again before getting nervous)
    ```bash
    export MACHINE_COUNT=5
    for i in `seq $MACHINE_COUNT`; do
        HOSTNAME="nuc-$i"
        ping -c 3 ${HOSTNAME}.lan # See comment on .lan TLD below
    done
    ```
    > Check that your router provides `<hostname>.lan` naming, if not, adjust to match
    > NOTE: If this fails, you might want to add each hostname to your /etc/hosts file. This is beyond the scope of this document.

1. Create (or use) SSH key on provisioning box (your laptop, another machine, etc).
    ```bash
    ssh-keygen -t ed25519 -f ~/.ssh/nucs
    ```
    > :warning: **DO NOT** use a passphrase

1. Setup SSH for passwordless access using SSH Configuration
    * Create or add to ~/.ssh/config
    * Replace `<user>` with the username created in step 1
    * Repeat block as needed to match the target machine count.
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

    > NOTE: The SSH key MUST be permissions `600` (rw owner only) and the config must be minimally `644` (rw owner, read other), but `600` is ok too

1. OPTIONAL - Some routers and/or systems may not have `.lan` suffix name resolution. Entries can be made to the `/etc/hosts` file (linux only) for DNS resolution for `nuc-x.lan`. Below is an example where the resolution is to the Router's gateway (may not be your destination depending on local router)

    ```
    192.168.1.1     nuc-1.lan nuc-2.lan nuc-3.lan nuc-4.lan nuc-5.lan
    ```

1. Copy SSH keys to all target machines
    ```
    ssh-copy-id ${user}@nuc-x.lan
    ```
    * Use the password and user created in step 1.
    * Repeat for all machines
1. Done! If you can SSH into all target machines without using a password or referencing an identity file, then you're ready to setup Ansible.

## Setup Ansible

### Goal: Setup Ansible on the provisioning machine

1. Provisioning machine needs to have Python 3.x (3.7+ is recommended).
    > Command `python` needs to be Python 3.x

1. Install Ansible
    ```bash
    pip install ansible
    ```
1. Install dnspython
    ```bash
    pip install dnspython
    ```

### Using Molecule



If you wish to use Molecule to develop the roles, install the following:

```bash
python -m pip install --user "molecule[ansible,docker,lint,gce]"
# not 100% sure that the above installs the gce provisioner for molecule, so repeat just in case
pip install molecule-gce
```
