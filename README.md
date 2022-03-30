# Overview

This project is an opinionated installation of Anthos Bare Metal and several Google Cloud Platform tools designed specifically for Consumer Edge requirements.

This project is a group of Ansible playbooks and bash scripts that are used to provision and manage Anthos bare metal instances given a hardware or cloud inventory.

There are two deployment target types: **Hardware** and **Cloud**. Both deployment types can co-exist, but are not in the same network space by default.

## TL;DR

There are three phases to installing Consumer Retail Edge

1. Setup baseline compute machines - Create and setup the underlying machines to be ready for provisioning
1. Provision inventory - Provision/install Consumer Edge onto the baseline compute maachines
1. Verify installation - Login to one of the machines and perform `kubectl` and other tool operations

### Terms to know

> **Target machine(s)** - The machine that the cluster is being installed into/onto (ie, NUC, GCE, etc). This is often called the "host" in public documentation.

> **Provisioning machine** - The machine that initiates the `ansible` run. This is typically a laptop or the cloud shell within the GCP console

---

## Quick Start - 1. Setup Baseline Compute

This **Quick Start** will use GCE instances to simulate physical hardware and utilize VXLAN overlays to simulate L2 networking support.

Please perform the following sequence of events:

1. Install docker on the **provisioning machine** (your machine, a cloud-top, etc)

    ```bash
    docker --version
    ```

1. This project uses Personal Access Tokens for the ACM authentication of the `root-repo`. [Create a new PAT token](https://docs.gitlab.com/ee/user/project/deploy_tokens/) and save the credentials for teh steps below. ![gitlab token](docs/Gitlab_token.png)
    1. Create the PAT with **read_repository** privilege.
    1. The "Token name" name that will be used as an environment variable **SCM_TOKEN_USER**.
    1. The produced token value that will be uesd as an environment variable **SCM_TOKEN_TOKEN**. Go to user **Preferences** on the top right corner.

1. Install or verify `gettext` is installed on the **provisioning machine**. Run `which envsubst` and if this fails, follow the below steps to install `gettext` binary

    * MacOS with Ports
        ```bash
        # MacOS + Ports
        sudo port install gettext
        ```

    * MacOS with Homebrew
        ```bash
        # MacOS + Brew
        brew install gettext
        brew link --force gettext
        ```

    * Debian/Ubuntu
        ```bash
        sudo apt install gettext
        ```

1. Create Google Service Account used for provisioning.  Skip this step if you have a properly authenticated GSA key located at `./build-artifacts/consumer-edge-gsa.json`

    ```bash
    # Follow prompts, generate a new key when prompted
    ./scripts/create-primary-gsa.sh
    ```

    * This will create a JSON key for the new GSA at `./build-artifacts/consumer-edge-gsa.json`

1. Create SSH keypair for communication between **provisioning machine** and **target machines**.

    1. Create new SSH keypair
        ```bash
        ssh-keygen -o -a 100 -t ed25519 -f ./build-artifacts/consumer-edge-machine2
        ```
        > When prompted, leave `passphrase` empty

1. Create configuration file (`.envrc`)

    ```bash
    # Create a default .envrc file (dot-file)
    envsubst < templates/envrc-template.sh > .envrc
    ```

    1. Edit the created `.envrc` file and substitute values. Replace all of the obvious variables (ie: `### replace me ###`)

    1. Replace the Gitlab Personal Access Token values inside `.envrc`

    1. Instanciate ENV variables inside current shell. Run source on the `.envrc` file to expose variables (advanced users can use `direnv` if installed and configured)

        ```bash
        source .envrc
        ```

1. Create GCE baseline instances.
    The quick start uses GCE intances to emulate Intel 11 NUCs (8CPU/16vCPU, 64GB RAM and 250GB storage).

    ```bash
    # Create 3 GCE instances w/ embedded init-script
    ./scripts/cloud/create-cloud-gce-baseline.sh -c 3
    ```

    > NOTE: Instance type defaults to `n1-standard-16`, stay within the `n1` or `n2` family due to hypervisor access visibility inside the OS.


## Quick Start - 2. Provision Inventory

In this phase, the compute machines have been created and a baseline has been established (ie: users created, minimal dependencies and public keys have been added to **target machines**). Now it is time to run `ansible`.

This phase involves the creation of a Docker provisioning image, inventory configuration settings and running the provisioning.

1. Creating and instanciating a `docker` provisioning image. A detailed explanation can be found in the [Docker build details](docker-build/README.md) file.

    ```bash
    cd docker-build
    gcloud builds submit --config cloud-build.yaml .
    cd ..
    ```

1. Create "inventory" file for Ansible provisioning

    ```bash
    envsubst < templates/inventory-cloud-example.yaml > inventory/gcp.yml
    ```

1. Upon completion, it's time to provision! Run the following and answer 'y' when propmted. This command will enter into the Docker image shell to run commands, do not `exit` until completed.
    ```bash
    ./install.sh
    ```

    > NOTE: The install script validates variables and dependencies that are used during provisioning.

1. Go get coffee, it can take 20-40 minutes to full provsion

1. If you completed with all 3 machines still in scope and no failures, you now have a fully provisioned Consumer Edge cluster!


## Quick Start - 3. Verifying

At this point, the cluster should be completed and visible in the `Kubernets Engine` and `Anthos` menus of GCP Console under `cnuc-1`. The quick start **does not** use OIDC (yet), so you will not be able to see the workloads and services of the cluser until you `login`. To do this, a token needs to be generated and cut-copy-pasted into the `Token` prompt of the login screen.

1. From within the Docker shell (if previously exited, run `./install.sh` again)

    ```bash
    ansible-playbook all-get-login-tokens.yaml -i inventory
    ```

    * Cut-copy-paste the token for `cnuc-1`

1. From the GCP console, click on the three vertical dots (menu) for the `cnuc-1` cluster and select `Login`

1. Select "Token" and paste in the value obtained from the previous command and submit

1. Workloads and services should now show up within the console as though it were a normal GKE cluster

1. Optional, logging in and running `kubectl` and `k9s` commands can be performed using SSH.

    * Run `./scripts/gce-status.sh` to produce the SSH commands for logging into each of the 3 machines

        ```bash
        ssh -F ./build-artifacts/ssh-config cnuc-1
        ```
    * Run commands on machine, the user will be `abm-admin`

        ```bash
        kubectl get nodes
        ```
    * `exit` to return to Docker shell

## Glossary

### Provisioning target types

> **Hardware** - Scripts and Playbooks designed to deploy onto hardware servers meeting requirements.
* In this project, all hardware machines will have `nuc` or `edge` as a prefixes on their hostname and variable names.

> **Cloud** - Scripts and Playbooks designed to be deployed into GCE Virtual Machines.
* In this project, all cloud machines will have `cnuc` as a prefix for hostname and variable names.
