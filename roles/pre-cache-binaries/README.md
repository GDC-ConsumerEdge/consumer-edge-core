# Overview

This role will use a pre-compressed (zip) bundle of binaries and a configuration file to install them into each node. The purpose is to avoid downloading them individually from the internet during provsioning

There are two primary methods to extract the `bundle.zip`.

### Local Folder
First is to put the bundle.zip on each machine at the same location (defaut: `/tmp/pre-cache/bundle.zip`)

### GCS Bucket in perimeter
Second is to use a GCS bucket that the `target-machine-gsa` Service Account can access (and is inside & allowed for VPC-SC permissions)

## Artifact Bundle

### Automated method (preferred)

1. Create the bundle by running the `./script/create-cache-bundle.sh` script (NOTE: will use the calling location to download, so best to run this script from a temp directory)
      > NOTE: The user calling the script needs to have access to the resources listed below in [Files](#files)

      ```bash
      # Create temp folder
      mkdir -p /tmp/bin-setup-folder
      cd /tmp/bin-setup-folder

      /<full-path-to-project-base>/scripts/create-cache-bundle.sh

      ls -al bundle.zip # this is the file you need to either upload or copy to all machines
      ```

1. Upon completion, the calling directory will have a `bundle.zip` file. This file contains all of the binaries externally downloaded

### Manual method

1. Download, chmod and name all of the below files and put them into the following folder structure

    ```bash
    bin/       # all of the binaries in this folder
    config.csv # name of each binary and where they belong on provisoned machine
    ```
1. Zip this whole folder and name it `bundle.zip`

# Files/Binaries

Create a new bundle using the helper script. NOTE: this computer and gcloud user need access to all of the resources.


| Binary Name                       | Download from                                                 | On-System At                                   |
|:----------------------------------|:--------------------------------------------------------------|:-----------------------------------------------|
| bmctl                             | `gs://anthos-baremetal-release/bmctl/${bmctl_version}/linux-amd64/bmctl` | /usr/local/bin |
| virtctl                           | `https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-linux-amd64` | /usr/bin/kubectl-virt |
| kubens                            | `https://github.com/ahmetb/kubectx/releases/download/v${kubectx_version}/kubens_v${kubectx_version}_linux_x86_64.tar.gz` | /usr/local/bin/kubens |
| kubectx                           | `https://github.com/ahmetb/kubectx/releases/download/v${kubectx_version}/kubectx_v${kubectx_version}_linux_x86_64.tar.gz` | /usr/local/bin/kubectx |
| k9s                               | `https://github.com/derailed/k9s/releases/download/${k9s_version}/k9s_Linux_x86_64.tar.gz` | /usr/local/bin/k9s |
| config-management-operator.yaml   | `gs://config-management-release/released/${acm_version}/config-management-operator.yaml` | /var/acm-configs//config-management-operator.yaml |
