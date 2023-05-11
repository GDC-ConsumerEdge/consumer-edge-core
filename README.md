# Overview

This project provides an opinionated installation of Anthos Bare Metal / GDC-V and several
Google Cloud Platform tools designed specifically for Consumer Edge
requirements.

There are two deployment target types: **Hardware** and **Cloud**. Both
deployment types can co-exist, but are not in the same network space by default.

**Cloud** deployments will have the virtual machines instantiated as a part of
the deployment process automatically.

**Hardware** targets require additional steps before execution of this deployment
process. See **Hardware Quick Start** below for additional details.

There are three phases to installing Consumer Retail Edge for either **Cloud** or **Hardware**:

1. Setup Baseline Compute - Create and setup the underlying machines
to be ready for provisioning
1. Provision Inventory - Provision/install Consumer Edge onto the baseline
compute machines
1. Verify Installation - Login to one of the machines and perform `kubectl` and
other tool operations

## Terms to know

> **Target machine**

*The machines that the cluster is being installed into/onto
(i.e., NUC, GCE, etc). This is often called a "host" in public
documentation.*

> **Provisioning machine**

*The machine that initiates the `ansible` run. This is typically a laptop or a
bastion host within the GCP console.*

> **Hardware**

*Physical systems deployed and network accessible. Hardware machines will
have `nuc` or `edge` as a prefixes on their hostname and variable names.*

> **Cloud**

*Google Cloud VMs deployed automatically via this project. All cloud
machines will have `cnuc` as a prefix for hostname and variable names.*

---

## Installation Types

### Cloud - GCE based

The easiest option to demo the solution is to use the GCE based instances. The GCE instances replicate NUCs or smaller profile machines. This option should not be used for production, but is great for lower level environments and development as the process is relatively quick.

### Hardware - Physical Machines

The primary option to provision the solution is to use physical hardware. Physical hardware requires not only one or three machines, but establishing a "baseline" state that includes the operating system, a user (`abm-admin`), establishing static IPs (DHCP reservation or Static IP configuration) and ensuring passwordless SSH connectivity from the Host to the Target.

---

## Both Installation Types

## ![Setup GCP Project](docs/img/1.png "1") Setup GCP Project

1. Create a GCP project with a valid billing account, then clone this repository.

1. Execute `setup.sh` on the **Provisioning Machine** and remediate until the script completes with the message `Your project is set up and ready for use. You will need to do a combination of the following options next:`...

    ```bash
    ./setup.sh
    ```

1. If RobinIO is the selected SDS Provider, see [Robin SDS Create Key](docs/ROBIN_SDS_CREATE_KEY.md)

1. This project uses Personal Access Tokens (PATs) for ACM's authentication of
    the `root-repo`. See [Create Gitlab PAT](docs/CREATE_GITLAB_PAT.md) to complete this step.

1. Verify the contents of generated `.envrc` are correct for your project and cluster.

1. Source the environment variables for the current shell

    ```bash
    source .envrc
    ```

1. Create the provisioning image. A detailed explanation can be found in the [Docker build details](docker-build/README.md) file. This will take a few minutes to complete:

    ```bash
    gcloud builds submit --config ./docker-build/cloudbuild.yaml .
    ```

### Competion of Step 1
* `echo $PROJECT_ID` results in your project ID being displayed
* `docker ps` can be run without `sudo` or elevated privledges
* `gcloud container images list --repository=gcr.io/$PROJECT_ID --filter="name~consumer-edge" --format="value(name)"` should print the Docker Image full name

------

## ![Setup Cloud](docs/img/2.png "2") Cloud Quick Start (Option 1)

This **Quick Start** will use GCE instances to simulate physical hardware and
utilize VXLAN overlays to simulate L2 networking support.

### 1. Setup GCE Host Instances

Execute the below steps and substeps in consecutive order.

1. Once the `setup.sh` provides the confirmation text as mentioned above, in the same directory as `setup.sh` execute:

    ```bash
    ./scripts/cloud/create-cloud-gce-baseline.sh -c 3
    ```

### 2. Setup Cloud Inventory

This phase leverages a container to ensure consistent and conflict free `ansible` deployment. Complete the steps below to initialize the container, deploy it to the **Provisioning machine**, and then execute `ansible` inside of the container.

1. Create "inventory" file for Ansible provisioning:

    ```bash
    envsubst < templates/inventory-cloud-example.yaml > inventory/gcp.yml
    ```

1. You are now ready to start provisioing based on cloud instances. Skip to "Step 3"

---

## ![Setup Cloud](docs/img/2.png "2") Hardware Quick Start (Option 2)

This **Quick Start** will use physical systems that are on an L2 network. These systems are recommended to be provisioned via the automated installer, have SSH keys shared to enable passwordless SSH authentication from **Provisioning machine**, and have Internet access (NAT recommended but proxy is supported) to complete the installation.

Execute the below steps and substeps in consecutive order.

### 1. Setup Baseline Compute (Hardware Quick Start)

There are two approaches to creating a baseline machine. This method is a bit more complex and requires some knowledge of Linux to complete.

1. Use the [Edge ISO Autoinstaller](https://consumer-edge.googlesource.com/edge-ubuntu-20-04-autoinstall/) project to create ISOs, flash the ISO to USB drives and boot to a baseline state.
    1. Add all of the hosts to `/etc/hosts` or to DNS service.
1. Option 2 is manual setup (for each host machine)
    1. Install Ubuntu 20.04LTS
    1. Add a user `abm-admin` with a known password for your safe keeping
    1. Setup user for passwordless `sudoer` access (see Internet for options)
    1. Setup networking to establish a Static IP. IPs should be reserved. IPs should also be a contigous range (ie: 192.168.3.11, 192.168.3.12, 192.168.3.13...)
        * Each host should have a short hostname (ie: edge-1, edge-2, edge-3)
    1. Use the public key established in Section 1 (`build-artifacts/consumer-edge-machine.pub`) to establish a passwordless SSH
        ```bash
        ssh-copy-id -i build-artifacts/consumer-edge-machine.pub abm-admin@<hostname>
        ```
        > NOTE: Use the password established when creating the user
    1. Add all of the hosts to `/etc/hosts` or to DNS service.

#### Verifying Physical Instances

1. This command should work if passwordless SSH keys and proper user are setup on each host
    ```bash
    ssh -F build-artifacts/ssh-config <hostname> "sudo ls /etc"
    ```

### 2. Provision Inventory (Hardware Quick Start)

1. Create "inventory" file for Ansible provisioning:

    ```bash
    envsubst < templates/inventory-physical-example.yaml > inventory/inventory.yml
    ```

1. Review `inventory/inventory.yml` to set the variables for your instances (ie: IP addresses for each host, cluster-level variables set, etc)

1. You are now ready to start provisioing based on physical instances. Skip to "Step 3"


## ![Provisioning Baselined Machines](docs/img/3.png "3") Provisioning Baselined Machines

1. Run the following and answer 'y' when propmted. This command will enter into the container image shell to run
commands, do not `exit` until completed.

    ```bash
    ./install.sh
    ```

    > NOTE: Depending on your terminal configuration, it might be hard to see,
    but there are a *TWO commands* that you will need to run once you are inside the
    container. Keep an eye on the output of the script for instructions.

    > NOTE: The provisioning is idempotent, failures occur from time-to-time based on environments. It is OK to re-run the process after adjusting a variable or fixing a condition.

    > NOTE: At this time, there is a technical limitation allowing only ONE cluster at-a-time to be provisioned.

1. Go get coffee, it can take 20-40 minutes to perform a full provsion

1. If you completed with all 3 machines still in scope and no failures, you now
have a fully provisioned Consumer Edge cluster!

### Verify
At this point cluster creation should be complete and visible in the
`Kubernetes Engine` and `Anthos` menus of GCP Console under `cnuc-1`. The quick
start **does not** use OIDC (yet), so you will not be able to see the workloads
and services of the cluser until you `login`. To do this, a token needs to be
generated and cut-copy-pasted into the `Token` prompt of the login screen.

1. From within the container shell (if previously exited, run `./install.sh` again)

    ```bash
    ansible-playbook all-get-login-tokens.yml -i inventory
    ```

    * Cut/Copy-paste the token for `<cluster-name>`

1. From the GCP console, click on the three vertical dots (menu) for the
`<cluster-name>` cluster and select `Login`

1. Select "Token" and paste in the value obtained from the previous command and
submit

1. Workloads and services should now show up within the console as though it
were a normal GKE cluster

1. Optional, logging in and running `kubectl` and `k9s` commands can be
performed using SSH.

    ### Cloud Method
    * Run `./scripts/gce-status.sh` to produce the SSH commands for logging
    into each of the 3 machines

    ### SSH to any machine
      ```bash
      ssh -F ./build-artifacts/ssh-config <host-name>
      ```

    * Run commands on machine, the user will be `abm-admin`

      ```bash
      kubectl get nodes
      ```
    * `exit` to return to container shell
