# Overview

This role will use a pre-compressed tarball (`.tar.gz`) bundle of binaries and install them into each node. The purpose is to avoid downloading them individually from the internet during provisioning.

There are two primary methods to provide the `pre-cache-bundle.tar.gz`.

### Local Folder
First is to put the tarball on each machine at the same location (default: `/tmp/pre-cache/pre-cache-bundle.tar.gz`).

### GCS Bucket in perimeter
Second is to use a GCS bucket that the `target-machine-gsa` Service Account can access (and is inside & allowed for VPC-SC permissions).

## Artifact Bundle

### Automated method (preferred)

1. Create the bundle by running the `scripts/create-cache-bundle.sh` script. Note: This script uses the calling location to save the tarball, so it's best to run this script from the workspace root or a temp directory.
      > NOTE: The user calling the script needs to have access to download the external dependencies.

      ```bash
      # Run from root of workspace
      ./scripts/create-cache-bundle.sh

      ls -al pre-cache-bundle.tar.gz # this is the file you need to either upload to GCS or copy to all machines
      ```

1. Upon completion, the calling directory will have a `pre-cache-bundle.tar.gz` file. This tarball replicates the exact file system structure required by the target machines.

### Manual method

1. Create a root staging structure representing exactly where each file should go.

    ```bash
    staging/
    ├── usr/
    │   ├── bin/
    │   │   └── kubectl-virt
    │   └── local/
    │       └── bin/
    │           ├── bmctl
    │           ├── k9s
    │           ├── kubectx
    │           ├── kubens
    │           └── kubestr
    ├── var/
    │   ├── abm-install/
    │   │   └── tools/
    │   │       ├── ncgctl-v1.12.0/
    │   │       └── google-cloud-sdk/
    │   ├── acm-configs/
    │   │   └── config-management-operator.yaml
    │   └── kube-ps1/
    │       └── kube-ps1-0.7.0/
    │           └── kube-ps1.sh
    └── tmp/
        ├── get-docker.sh
        ├── add-monitoring-agent-repo.sh
        └── add-logging-agent-repo.sh
    ```
1. Compress this folder hierarchy directly:
    ```bash
    tar -czvf pre-cache-bundle.tar.gz -C staging .
    ```

# Files/Binaries

Create a new bundle using the helper script. NOTE: this computer and gcloud user need access to all of the resources.

| Binary Name                       | On-System At                                   |
|:----------------------------------|:-----------------------------------------------|
| bmctl                             | /usr/local/bin/bmctl |
| virtctl                           | /usr/bin/kubectl-virt |
| kubens                            | /usr/local/bin/kubens |
| kubectx                           | /usr/local/bin/kubectx |
| k9s                               | /usr/local/bin/k9s |
| kubestr                           | /usr/local/bin/kubestr |
| config-management-operator.yaml   | /var/acm-configs/config-management-operator.yaml |
| kube-ps1.sh                       | /var/kube-ps1/kube-ps1-0.7.0/kube-ps1.sh |
| ncgctl                            | /var/abm-install/tools/ncgctl-... |
| gcloud sdk                        | /var/abm-install/tools/google-cloud-sdk/ |
| get-docker.sh                     | /tmp/get-docker.sh |
