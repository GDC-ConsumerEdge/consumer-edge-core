# Overview

This project is an opinionated installation of Anthos Bare Metal and several Google Cloud Platform tools designed specifically for Consumer Edge requirements.

This project is a group of Ansible playbooks and bash scripts that are used to provision and manage Anthos bare metal instances SPECIFICALLY for deployment into GCP in order to simulate or test various aspects of the Anthos Bare Metal / Consumer Edge Core platform.

This README will detail how to leverage the scripts in the repo in order to configure a Google Cloud employee organization & project or another Google Cloud project to support running this solution.

## TL;DR

There are three phases to installing Consumer Retail Edge

1. Configuration of Google Cloud org policies - Ensure that various organization policies are disabled for this project to ensure proper operations (i.e. External IP access, VM IP Forwarding, etc.) & deployment of the Bastion Host.
1. Provision VMs - Configure a bastion VM (Debian 11 VM deployed by the user) and creation of an GDC-V 3-node cluster
1. Verify installation - Login to one of the machines and perform `kubectl` and other tool operations

### Terms to know

> **Target machine(s)** - The machine that the cluster is being installed into/onto (ie, NUC, GCE, etc). This is often called the "host" in public documentation.

> **Provisioning machine** - The machine that initiates the `ansible` run. This is typically a bastion VM deployed by the user. CloudShell can also be used but some actions take around 20-40 minutes which coudl cause CloudShell to timeout and disconnect. In general, the scripts are built to be idempotent meaning the scripts and ansible are built to be run multiple times without breaking things. All edge cases are not tested, so there may be dragons.

---

## Quick Start - 1. Setup Baseline Compute

This **Quick Start** will use GCE instances to simulate physical hardware and utilize VXLAN overlays to simulate L2 networking support.

Please perform the following sequence of events:

1. Edit `./pre-setup-org-network-bastion.sh` to set the proper GCP ZONE for deployment. Ensure that `./templates/envrc-template.sh` matches so that both the bastion host and the VM's are deployed to the same Zone. Tt is highly recommended to use this script to allow Org Policies, set FW rules, and create the Debian 11 bastion VM. This step could be skipped if you have already performed these tasks manually:

   ```shell
   ./pre-setup-org-network-bastion.sh
   ```

1. Pull the Consumer Edge Core repo into the bastion VM. As of the time of this writing - the source is contained @ https://consumer-edge.googlesource.com/core/. Once the code is uploaded to the bastion VM, `cd` into the directory.

1. This project uses Personal Access Tokens for the ACM authentication of the `root-repo`. [Create a new PAT token](https://docs.gitlab.com/ee/user/project/deploy_tokens/) and save the credentials for teh steps below. ![gitlab token](docs/Gitlab_token.png)

   1. Create the PAT with **read_repository** privilege.
   1. The "Token name" name that will be used as an environment variable **SCM_TOKEN_USER**.
   1. The produced token value that will be used as an environment variable **SCM_TOKEN_TOKEN**. Go to user **Preferences** on the top right corner.

1. Locate `setup.sh`. This script will install all required dependencies (only currently works for a Debian 11 VM). Once dependencies are installed, it will create an SSH key to be shared with the created VMs. The primary GSA will be created and then it will use Google Cloud KMS to encrypt this key (but it will leave the unencrypted version in place for user action to delete/leverage). It will then execute the creation of a 3-node cluster named cnuc-1, cnuc-2, cnuc-3. Next, it will create the Docker container for Ansible installation and store it in GCR. Finally, it will prepare the inventory file for Ansible and state that install.sh is ready to run:

   ```bash
   ./setup-sh
   ```

1. Upon completion, it's time to provision! Run the following and answer 'y' when prompted. This command will enter into the Docker image shell to run commands, do not `exit` until completed. NOTE: If you see a yellow warning - please read it carefully. If you are deploying to GCP and the yellow warning states that the physical inventory file is missing - it is safe to press Y to continue as it should show a Green text confirmation that GCP inventory was located!

   ```bash
   screen
   ./install.sh
   ```

   > NOTE 1: The install script validates variables and dependencies that are used during provisioning.

   > NOTE 2: `screen` is recommended due to the length of time the script can take to run. If you are disconnected use `screen -r -D` to reconnect to the running script!

1. Go get coffee, it can take 20-40 minutes to fully provision

1. If you completed with all 3 machines still in scope and no failures, you now have a fully provisioned Consumer Edge cluster!

## Quick Start - 3. Verifying

At this point, the cluster should be completed and visible in the `Kubernetes Engine` and `Anthos` menus of GCP Console under `cnuc-1`. The quick start **does not** use OIDC (yet), so you will not be able to see the workloads and services of the cluster until you `login`. To do this, a token needs to be generated and cut-copy-pasted into the `Token` prompt of the login screen.

1. From within the Docker shell (if previously exited, run `./install.sh` again)

   ```bash
   ansible-playbook all-get-login-tokens.yml -i inventory
   ```

   - Cut-copy-paste the token for `cnuc-1`

1. From the GCP console, click on the three vertical dots (menu) for the `cnuc-1` cluster and select `Login`

1. Select "Token" and paste in the value obtained from the previous command and submit

1. Workloads and services should now show up within the console as though it were a normal GKE cluster

1. Optional, logging in and running `kubectl` and `k9s` commands can be performed using SSH.

   - Run `./scripts/gce-status.sh` to produce the SSH commands for logging into each of the 3 machines

     ```bash
     ssh -F ./build-artifacts/ssh-config cnuc-1
     ```

   - Run commands on machine, the user will be `abm-admin`

     ```bash
     kubectl get nodes
     ```

   - `exit` to return to Docker shell

## Glossary

### Provisioning target types

> **Hardware** - Scripts and Playbooks designed to deploy onto hardware servers meeting requirements.

- In this project, all hardware machines will have `nuc` or `edge` as a prefixes on their hostname and variable names.

> **Cloud** - Scripts and Playbooks designed to be deployed into GCE Virtual Machines.

- In this project, all cloud machines will have `cnuc` as a prefix for hostname and variable names.
