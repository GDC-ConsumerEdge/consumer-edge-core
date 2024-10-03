# Overview

This project provides an opinionated installation of GDC Software Only and several
Google Cloud Platform tools designed specifically for Consumer Edge requirements.

There are two deployment target types: **Hardware** and **Cloud**. Both deployment types can co-exist for a project, but are not in the same network space by default.

The primary tooling to provision **Hardware** or **Cloud** clusters is performed with Ansible via a Docker container. Once built, the docker container provides the runtime with all necessary dependencies so the provisioner does not need to modify the host machine. The docker container also mounts the project folder structure containing the configuration contexts.

**Cloud** targets will have the virtual machines instantiated as a part of the deployment process automatically. GCE VMs will be used in the target GCP Project simulating physical hardware

**Hardware** targets physical PCs or servers and require additional steps before execution of this deployment process. See **Hardware Quick Start** below for additional details.

## Install Phases

There are three phases to installing Consumer Retail Edge for either **Cloud** or **Hardware**:

1. Establish Baseline Compute - Create and setup the underlying machines to be ready for provisioning
1. Configure & Provision - Provision/install Consumer Edge onto the baseline compute machines
1. Verify Installation - Login to one of the machines and perform `kubectl` and other tool operations

### Terms to know

> **Target machine**

* The machines that the cluster is being installed into/onto
(i.e., NUC, GCE, etc). This is often called a "host" in public
documentation.*

> **Provisioning machine**

* The machine that initiates the `ansible` run. This is typically a laptop or a
bastion host within the GCP console.*

> **Hardware**

* Physical systems deployed and network accessible. Hardware machines will
have `nuc` or `edge` as a prefixes on their hostname and variable names.*

> **Cloud**

* Google Cloud VMs deployed automatically via this project. All cloud
machines will have `cnuc` as a prefix for hostname and variable names.*

> **Configuration Context**

* `build-artifacts/` is a symbolic link to a folder with the following pattern: `build-artifacts-<cluster-name>`. Using the script `./script/change-instance-context.sh`, configuration settings for a cluster or cluster group can be kept locally. Future implementations will provide the ability to compress and upload & download the contexts to a GCS bucket. The `build-artifact/` symlink should not be manually edited, please use the `./script/change-instance-context.sh` script to create new or change contexts for a run.

---

## Installation Types

### Cloud - GCE based

The easiest option to demo the solution is to use the GCE based instances. The GCE instances replicate NUCs or smaller profile machines. This option should not be used for production, but is great for lower level environments and development as the process is relatively quick.

### Hardware - Physical Machines

The primary option to provision the solution is to use physical hardware. Physical hardware requires not only one or three machines, but establishing a "baseline" state that includes the operating system, a user (`abm-admin`), establishing static IPs (DHCP reservation or Static IP configuration) and ensuring passwordless SSH connectivity from the Host to the Target.

---

## Installation

### ![Setup GCP Project](docs/img/1.png "1") Setup GCP Project

1. Create a GCP project with a valid billing account, then clone this repository.

1. Execute `setup.sh` on the **Provisioning Machine** and remediate until the script completes with the message `Your project is set up and ready for use. You will need to do a combination of the following options next:`

    ```bash
    # Run
    ./setup.sh
    ```

    > Note: The `setup.sh` will create a Docker image in your project's Artifact Registry. The purpose is to use the docker image as a build and provisioning base so the provisioning machine does not need to manage dependencies.

1. If SymCloud (formerly Robin.io) is the selected SDS Provider, see [Robin SDS Create Key](docs/ROBIN_SDS_CREATE_KEY.md)

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

## ![Setup Cloud](docs/img/2.png "2") Cloud Quick Start (Install Option 1)

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
    envsubst < templates/inventory-cloud-example.yaml > build-artifacts-example/gcp.yml
    ```

1. You are now ready to start provisioing based on cloud instances. Skip to "Step 3"

---

## ![Setup Cloud](docs/img/2.png "2") Hardware Quick Start (Install Option 2)

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
    envsubst < templates/inventory-physical-example.yaml > build-artifacts-example/inventory.yml
    ```

1. Review `build-artifacts/inventory.yml` to set the variables for your instances (ie: IP addresses for each host, cluster-level variables set, etc)

1. You are now ready to start provisioing based on physical instances. Skip to "Step 3"


## ![Provisioning Baselined Machines](docs/img/3.png "3") Provisioning Baselined Machines

1. Create any overrides to variables using the `templates/instance-run-vars-template.yaml`. Adjust to match the provisioning instance run needs

    ```bash
    envsubst < templates/instance-run-vars-template.yaml > build-artifacts/instance-run-vars.yaml
    ```

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

## Using more than 1 cluster?

Consumer Edge is setup to provision one cluster at a time (future, multiple at a time). In the meantime, here are a few suggestions

* Create a symlink to your `build-artifacts/` folder so it is easy to swap back/forth
    ```bash
    cp -r build-artifacts/ build-artifacts-1
    ln -s build-artifacts-1 build-artifacts
    # repeat as needed
    ```

## Network Pre-requisites

Several domains are used in the deployment of this solution and will need to be allow-listed outbound if domain fitering is used.

Please allow-list the following domains and their ports:

| Domain Pattern | Port & Protocols | Notes/Explanation | Optional |
|:---|:---:|:---|:---:|
| `gcr.io`<br/>`*.gcr.io`<br/>`*.pkg.dev`                        | 443 TCP | Many of the GDC core packages are deployed to gcr.io and pkg.dev (Artifact Registry). This pattern covers all regions (ie: eu.gcr.io, asia.gcr.io, etc) | No |
| `*.googleapis.com`<br/>`*.gdce.googleapis.com`                 | 443 TCP | Google Services like GKE Hub, CloudOps, Secrets Manager, IAM, Compute, Network, GDC, etc | No |
| `*.google`                                                     | 443 TCP | Covers Google services deployed on GCP not via GCP APIs | Yes |
| `registry.k8s.io`<br/>`k8s.io`                                 | 443 TCP | Kubernetes public container registry (ie: Kind cluster, k8s containers, etc) | No |
| `github.com`<br/>`*.github.com`<br/>`ghcr.io`<br/>`*.ghcr.io`<br/>`*.githubusercontent.com`  | 443 TCP | Containers and Utilities deployed in GitHub | No |
| `quay.io`<br/>`*.quay.io`                                      | 443 TCP | VirtVNC and some more mature container apps | No |
| `*.gitlab`                                                     | 443 TCP | External Secrets and Cluster Trait Repositories | No* |
| `*.ubuntu.com`                                                 | 443 TCP<br/> 80 TCP| Ubuntu services | No |
| `*.canonical.com`<br/>`*.snapcraft.io`<br/>`*.snapcraftcontent.com` | 443 TCP | Package manager for Ubuntu and Canonical services via Snap | No |
| `*.docker.com`                                                 | 443 TCP | Docker software and dependencies | No |
| `packages.cloud.google.com`                                    | 443 TCP | Google CLI Tools and Binaries | No |
| `time.google.com`<br/>`time1.google.com`<br/>`time2.google.com`<br/>`time3.google.com`<br/><br/>`pool.ntp.org`<br/>`0.pool.ntp.org`<br/>`1.pool.ntp.org`<br/>`2.pool.ntp.org`<br/>`3.pool.ntp.org`| 123 UDP | Time sync server (pick one or the other, not Google and NTP.org) | Yes |

> *: Required only if not re-hosting CTRs

