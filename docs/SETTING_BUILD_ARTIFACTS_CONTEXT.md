# Overview

This page describes what **Build Context** is, why it's needed, and how to manage the lifecycle of them.

## What is Build Contexts?

Build Contexts are folders containing a certain set of convention based files that link to configuration used in installing and administering the GDC Consumer Clusters.

Build Contexts consists of `symlink` (ie: `ln -s <target> <file>`) folders linking to the `build-artifacts/ folder at the root of the project. These folders are never checked in, but can be syncronized from GCS Buckets (still in progress)

## Creating a new Context

1. Start with initiating the script `./scripts/change-instance-context.sh [a name]`.

    1. This will prompt to create a new Build Context, select 'y'
    1. Future work will include a guided setup process to reduce new context creation efforts.

1. With a text and file editor, update the following files

    1. `add-hosts` - set the hosts of the machines with their IPs and host names
    1. Copy both the Public and Private SSH keys to this new folder and call them `consumer-edge-machine.pub` (public) and `consumer-edge-machine` (private)
    1. Update the `envrc` file to match the desired variables for your context's install
    1. Update the `instance-run-vars.yaml` file to match your desired overrides
    1. Change the `inventory-example.yaml` to `inventory.yaml`. Modify the file to include the specific host-names and IPs of your physical machines
    1. Copy the `provisioning-gsa.json` GSA key is used to provision nodes (note: this may only appear AFTER `./setup.sh` has been run, so come back and add after `./setup.sh` has been run, after setting these variables)
    1. Change the file `gcp-example.yaml` to `gcp.yaml` and upate the variables in the file to the desired instance.
    1. Copy the desired Robin/SymCloud TAR file into this folder. Versions can be found at gsutil ls -al gs://robin-partners/release/ (permission is required and obtained with valid Robin License agreement)

1. The context folder should represent something similar to this

    ```shell
    ├── build-artifacts-[[SOME NAME]]
    │   ├── add-hosts
    │   ├── consumer-edge-machine
    │   ├── consumer-edge-machine.pub
    │   ├── envrc
    │   ├── gcp.yml
    │   ├── instance-run-vars.yaml
    │   ├── inventory.yaml
    │   ├── provisioning-gsa.json
    │   ├── README.md
    │   ├── robin-install-5.X.XX-XX.tar
    │   └── ssh-config
    ```
1. Re-run `./scripts/change-instance-context.sh` and see the `*` next to the new context.

## Deleting Contexts

Deleting is simple, remove the folder and re-run `./scripts/change-instance-context.sh` to show the new context is no longer available.

## Syncronizing with GCS buckets

> TBD: This is a work in progress